# Pixel Russian Networks & 5G (n79/n78) / VoLTE / VoWiFi Fix

> **Комплексная адаптация модема Google Pixel 8 Pro (Shannon 5300 / Tensor G3) для работы в сетях операторов РФ (МегаФон, Билайн, МТС, T2 / Tele2, Т-Банк) с активацией диапазона 5G n79, VoLTE, VoWiFi, VoNR и полной агрегации частот LTE-Advanced.**
> 
> *Подходит для Android 14, 15, 16, 17+ (проверено на сборке `CP4A.261105.040.A1` / Android 17).*

---

## 📌 Предыстория и постановка задачи

После очередного обновления прошивки моего Google Pixel 8 Pro (американская версия `G1MNW`, baseband `g5300i-260818-261007-B-16536936`) стандартно слетает нормальная поддержка российских сетей:
1. Google программно блокирует VoLTE и VoWiFi для регионов, где Pixel официально не продаётся.
2. 5G полностью отключен в `CarrierConfig`.
3. В России недавно началось активное тестирование и внедрение 5G в диапазоне **n79 (4.4 – 5.0 ГГц)** и **n78 (3.4 – 3.8 ГГц)**. По умолчанию в прошивке Pixel диапазон n79 для российских SIM-карт отключен даже на уровне модемных таблиц UE Capability.
4. Агрегация частот LTE (LTE-Advanced / 4G+) для российских операторов либо отсутствует, либо ограничена простейшими связками, что снижает скорость мобильного интернета в 2–3 раза.

Я поставил цель: **сделать идеальное, чистое и автономное решение без костылей и постоянных фоновых демонов**, которое:
- Разблокирует VoLTE, VoWiFi, VoNR на обеих SIM-картах одновременно.
- Включит полную поддержку 5G (NSA + SA), включая диапазоны **n78** и **n79**.
- Активирует агрегацию частот LTE-A (3CA/4CA/5CA) с поддержкой MIMO 4x4.
- Не держит в оперативной памяти фоновых приложений (вроде Pixel IMS / MaxManager), сохраняя 100% автономности аккумулятора.
- Работает полностью **systemless** (через KernelSU / Magisk / APatch), не затрагивая read-only разделы и образ модема.

---

## 🔬 Реверс-инжиниринг модема Shannon 5300

В Pixel 8 Pro установлен модем Samsung Shannon 5300. Прошивка модема монтируется в `/mnt/vendor/modem_img/images/<версия_модема>/`.

### 1. Как модем определяет оператора (`confpack/cfg.db`)
В директории `confpack/` лежит база данных SQLite `cfg.db`. В ней содержатся таблицы `confman_carrier_id` и `confman_carrier_id_mccmnc`.
При анализе выяснилось:
- Для российских операторов (MegaFon `25002`, Beeline `25099`, MTS `25001`, Tele2 `25020`, Tinkoff `25062` и др.) нет отдельных профилей.
- Модем сваливается в профиль по умолчанию — **`wildcard`** (Carrier ID 0).

### 2. Ограничения в `uecap/WILDCARD.binarypb`
В каталоге `uecap/` находятся скомпилированные Protobuf-файлы возможностей модема (UE Capabilities) для разных операторов.
- В профиле `WILDCARD.binarypb` диапазон **n79 полностью вырезан** на уровне RRC filtering!
- Набор комбинаций агрегаций частот (LTE-A CA combos) в `WILDCARD` сильно урезан по сравнению с профилями крупных мировых операторов.
- В то же время японский профиль оператора NTT Docomo (`jp_dcm` / `DCM.binarypb` / хэш `b55ced10229b773535c45e8f216b1fa946a647f0`):
  * **Аппаратно включает Band n79** (так как в Японии n79 является основным национальным диапазоном 5G).
  * Имеет богатейшую матрицу агрегаций LTE-A (B1+B3, B3+B7, B1+B3+B7, B3+B8+B20, B38+B38 и др. до 4CA/5CA).

---

## 🛠 Архитектура решения

Решение состоит из двух скоординированных уровней: **уровень модема** и **уровень ОС Android**.

### 1. Уровень модема (Shannon RIL / Firmware Bind-Mount)
Через ранний скрипт `post-fs-data.sh`:
- Модифицируется база `cfg.db`: российские Carrier ID (1016, 1681, 1678, 1020, 1028, 2142 и др.) и PLMN привязаны к конфигурационному блоку Docomo (`b55ced10229b773535c45e8f216b1fa946a647f0`).
- В `uecap/WILDCARD.binarypb` внедрена полная карта UE Capability с поддержкой n79.
- Обе модификации монтируются методом `mount --bind` прямо поверх оригинальных файлов в `/mnt/vendor/modem_img/...` с обязательным SELinux контекстом `u:object_r:modem_img_file:s0`. Физический образ модема остаётся нетронутым!

### 2. Zero-Daemon Архитектура (Уровень ОС Android)
Стандартные модули запускают постоянные Android-приложения (например, `MaxManager` от Pixel IMS), которые постоянно висят в процессах, тратят память, могут выгружаться OOM Killer и требуют фоновых разрешений.

В этом модуле реализован принципиально иной подход:
- Написан компактный DEX-рантайм `system/bin/Applier.dex`.
- В скрипте `service.sh` при старте системы один раз вызывается:
  ```sh
  /system/bin/app_process -Djava.class.path=/data/adb/modules/pixel_ru_network_fix/system/bin/Applier.dex /system/bin Applier
  ```
- `Applier` подключается напрямую к IPC-сервису `ICarrierConfigLoader` через Android Binder под правами root UID 0 и применяет полный перечень оверрайдов для всех активных слотов SIM:
  * `carrier_volte_available_bool = true`
  * `carrier_wfc_ims_available_bool = true`
  * `carrier_nr_availabilities_int_array = [1, 2]` (NSA + SA)
  * `additional_nr_advanced_bands_int_array = [1, 3, 8, 28, 41, 78, 79]` (n78 + n79)
  * `vonr_enabled_bool = true`
  * `show_4g_for_lte_data_icon_bool = true` & `hide_lte_plus_data_icon_bool = false` (отображение 4G+ / LTE+)
  * `carrier_cross_sim_ims_available_bool = true` (VoWiFi через мобильный интернет второй SIM-карты)
  * `editable_wfc_mode_bool = true` (разблокировка меню выбора предпочтительной сети для звонков)
- Сразу после выполнения процесс завершается. **В оперативной памяти остаётся 0 фоновых процессов.**

---

## 📊 Результаты и верификация (Live Dumps)

Тестирование проводилось на Pixel 8 Pro с двумя активными SIM-картами (SIM 1 — МегаФон, SIM 2 — Билайн).

### 1. Агрегация частот LTE-A (3CA на Билайн):
```
notifyServiceStateForSubscriber: subId=2 phoneId=1 state={
    mVoiceRegState=0(IN_SERVICE), mDataRegState=0(IN_SERVICE),
    mCellBandwidths=[15000, 15000, 10000],
    mOperatorAlphaLong=beeline,
    getRilVoiceRadioTechnology=14(LTE),
    isUsingCarrierAggregation=true,
    mNetworkRegistrationInfos=[...]
}
```
> **Результат**: Агрегируются три полосы частот (15 МГц + 15 МГц + 10 МГц, суммарно 40 МГц полосы). Флаг `isUsingCarrierAggregation = true`.

### 2. IMS-сервисы (VoLTE / VoWiFi / IWLAN):
```
ImsRegistrationController:
  [0] subId=1 (MegaFon) -> Registered over IWLAN (Wi-Fi Calling) / LTE (VoLTE supported)
  [1] subId=2 (Beeline) -> Registered over IWLAN (Wi-Fi Calling) / LTE (VoLTE supported)
```

### 3. Диапазоны 5G:
```
carrier_nr_availabilities_int_array = [1, 2]
additional_nr_advanced_bands_int_array = [1, 3, 8, 28, 41, 78, 79]
vonr_enabled_bool = true
```

---

## 📥 Установка

1. Скачайте релизный архив [`Pixel_8_Pro_RU_5G_VoLTE_Fix.zip`](./Pixel_8_Pro_RU_5G_VoLTE_Fix.zip).
2. Откройте менеджер рут-прав (**KernelSU**, **Magisk** или **APatch**).
3. Перейдите во вкладку **Модули** -> **Установить из хранилища**.
4. Выберите архив и дождитесь окончания прошивки.
5. Перезагрузите устройство.

---

## 📁 Структура репозитория

```
├── Pixel_8_Pro_RU_5G_VoLTE_Fix.zip  # Готовый модуль для прошивки
├── module.prop                      # Метаданные модуля Magisk/KernelSU
├── customize.sh                     # Скрипт установки прав доступа
├── post-fs-data.sh                  # Ранний bind-mount баз модема в /mnt/vendor/modem_img
├── service.sh                       # Однократный запуск binder-апплайера при boot_completed
├── config.json                      # Конфигурация параметров CarrierConfig
├── confpack/
│   └── cfg.db                       # Пропатченная SQLite-база модема Shannon
├── uecap/
│   └── WILDCARD.binarypb            # Кастомная UE Capability с поддержкой n79 и агрегаций
└── system/
    └── bin/
        └── Applier.dex              # Скомпилированный DEX-бридж к ICarrierConfigLoader
```

---

## ⚖️ Лицензия
MIT License. Проект создан в исследовательских и образовательных целях для адаптации устройств Google Pixel под региональные особенности сетей связи.
