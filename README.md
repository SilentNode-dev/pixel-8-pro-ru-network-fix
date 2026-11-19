# Pixel Russian Networks & 5G (n78/n79) / VoLTE / VoWiFi Fix

> **Низкоуровневый системный модуль (KernelSU / Magisk / APatch) для аппаратной адаптации модемов Samsung Shannon (Google Tensor G2/G3/G4) под сети операторов РФ: МегаФон, МТС, Билайн, Т2 (Tele2), Т-Банк.**
> 
> Разблокирует аппаратный диапазон 5G n79, агрегацию частот LTE-Advanced (до 5CA), VoLTE, VoWiFi, VoNR и Cross-SIM IMS без установки сторонних фоновых приложений.
> 
> **Совместимость:** Android 14, 15, 16, 17+ (проверено на Pixel 7, 7 Pro, 8, 8 Pro, 9, 9 Pro).

---

## ⚡ Технические возможности

### 1. Модемный уровень (Baseband & Radio)
* **Активация 5G NR (NSA + SA)**: включение диапазонов **n78 (3.4–3.8 ГГц)** и **n79 (4.4–5.0 ГГц)**, а также n1, n3, n8, n28, n41, DSS.
* **Снятие RRC-фильтрации n79**: устранение аппаратного блокирования диапазона n79 в модеме Shannon 5300 через подмену стека `uecap`.
* **Агрегация частот LTE-Advanced (4G+)**: разблокировка полной матрицы агрегаций (3CA / 4CA / 5CA) с поддержкой MIMO 4x4 и модуляции 256-QAM (комбинации B1+B3, B3+B7, B1+B3+B7, B7+B20, B3+B38, B38+B38 и др.).
* **Голос нового поколения (VoNR / Vo5G)**: аппаратная и программная поддержка голосовых вызовов высокой чёткости внутри сетей 5G Standalone.
* **Кодеки сверхвысокой чёткости**: принудительное включение речевых кодеков **EVS (Enhanced Voice Services / HD Voice+)** и AMR-WB.

### 2. Подсистема IMS (IP Multimedia Subsystem)
* **VoLTE (Voice over LTE)**: полноценная работа пакетной передачи голоса на обеих SIM-картах (Dual SIM Dual Standby — физ. SIM + eSIM).
* **VoWiFi (Wi-Fi Calling)**: прямое подключение к шлюзам ePDG российских операторов, разблокировка ручного выбора приоритета сети (Cellular preferred / Wi-Fi preferred).
* **Backup Calling (Cross-SIM IMS)**: возможность совершать звонки по VoWiFi через мобильный интернет второй SIM-карты при отсутствии покрытия на первой.
* **ViLTE / VT (Video over LTE)**: поддержка нативных операторских видеозвонков.

### 3. Системная интеграция и оптимизация
* **Zero-Daemon Архитектура**: модуль не запускает постоянных служб и не требует установленного APK. Байткод отрабатывает один раз при загрузке системы (`boot_completed`) и выгружается. **0 МБ ОЗУ и 0% расхода батареи в фоне**.
* **Systemless Bind-Mount**: файлы модема монтируются на этапе `post-fs-data` поверх оригинальных с сохранением контекстов SELinux (`u:object_r:modem_img_file:s0`). Системные разделы остаются read-only, сохраняется прохождение проверок целостности (Play Integrity / SafetyNet).
* **Корректная индикация**: разблокировано отображение значков `4G+`, `LTE+` и `5G` в статус-баре в соответствии с реальной активностью несущих.

---

## 🔬 Архитектура и принцип работы

Модуль воздействует на стек связи комплексно — от физических образов модема до IPC-сервисов Android Framework:

```
[ Этап 1: post-fs-data.sh ]
       │
       ├── mount --bind uecap/WILDCARD.binarypb ➔ /mnt/vendor/modem_img/.../uecap/WILDCARD.binarypb
       │     └─► [Аппаратная разблокировка n79 + матрица агрегаций LTE-A Docomo]
       │
       └── mount --bind confpack/cfg.db ➔ /mnt/vendor/modem_img/.../confpack/cfg.db
             └─► [Маппинг PLMN/MCC-MNC РФ операторов к профилю модема Shannon]

[ Этап 2: service.sh @ boot_completed ]
       │
       ├── setprop persist.dbg.* & persist.radio.*
       │     └─► [Активация флагов радиомодема: VoLTE, VoWiFi, VoNR, IMS]
       │
       ├── content update telephony/siminfo
       │     └─► [Активация переключателей в системных настройках Android]
       │
       └── app_process ➔ system/bin/Applier.dex (UID 0)
             └─► [Прямая инъекция операторских параметров в ICarrierConfigLoader]
```

### 1. Подмена матрицы возможностей модема (`uecap/WILDCARD.binarypb`)
В Pixel 8 Pro модем Samsung Shannon 5300 использует скомпилированные Protobuf-файлы возможностей (UE Capabilities). Для операторов стран, где Pixel официально не продаётся, модем использует профиль `WILDCARD.binarypb`. В нём Google принудительно:
1. Вырезал диапазон n79 на уровне RRC-фильтрации.
2. Ограничил доступные комбинации агрегации несущих (CA combos).

Модуль производит бесшовную подмену `WILDCARD.binarypb` на модифицированный профиль на базе японского оператора NTT Docomo (хэш `b55ced10229b773535c45e8f216b1fa946a647f0`), где диапазон n79 является национальным стандартом и активен аппаратно, а матрица агрегаций содержит все используемые в РФ связки частот.

### 2. Прямой инжектор CarrierConfig (`Applier.dex`)
Вместо тяжёлых пользовательских приложений с правами доступности, модуль использует легковесный скомпилированный DEX-мост. При старте системы `service.sh` запускает:
```sh
/system/bin/app_process -Djava.class.path=$MODDIR/system/bin/Applier.dex /system/bin Applier
```
`Applier` связывается с системным сервисом `ICarrierConfigLoader` через Android Binder напрямую под правами root (UID 0), применяя оверрайды для всех активных SIM-слотов, после чего немедленно завершает работу.

---

## ⚖️ Сравнение: Наш KSU-модуль vs Pixel-IMS-5G (barrylk)

Проект [`barrylk/Pixel-IMS-5G`](https://github.com/barrylk/Pixel-IMS-5G) (эволюция утилиты kyujin-cho с добавлением модемных наработок Displax/vchikalkin) является альтернативным решением. Ниже приведено объективное техническое сравнение:

| Критерий | `Pixel-IMS-5G` (barrylk) | Наш KSU-модуль (`pixel_ru_network_fix`) |
| :--- | :--- | :--- |
| **Форм-фактор** | Пользовательский APK + встроенный Root/Shizuku сервис | Чистый системный headless-модуль (KernelSU / Magisk / APatch) |
| **Пользовательский интерфейс** | ✅ **Есть** (графический интерфейс Liquid Glass, мониторинг) | ❌ **Нет** (управление штатно через настройки Android) |
| **Живой монитор сети (Field Test)** | ✅ **Есть** (отображение полос CA, PCI, RSRP/RSRQ на экране) | ❌ Нет (диагностика через `dumpsys telephony.registry` или NetMonster) |
| **Патч базы операторов `cfg.db`** | ✅ Патчит оригинальный файл базы через приложение | ✅ Монтирует готовую оптимизированную базу при старте ядра |
| **Патч возможностей `uecap`** | ❌ **Не патчит** (файлы `uecap` не затрагиваются) | ✅ **Монтирует кастомный `WILDCARD.binarypb`** |
| **Диапазон 5G n79 (РФ)** | ⚠️ **Заблокирован модемом** (RRC-фильтрация в `WILDCARD` остаётся) | ✅ **Полностью разблокирован** на аппаратном уровне |
| **Матрица агрегации LTE-A (4G+)** | ⚠️ Базовая глобальная (из профиля PTCRB) | ✅ **Максимальная** (японская матрица Docomo 3CA/4CA/5CA + MIMO 4x4) |
| **Региональная оптимизация** | Универсальная (Шри-Ланка, Индия, Азия, PTCRB) | **Точечно под РФ** (МегаФон, МТС, Билайн, Т2, Т-Банк) |
| **Нагрузка на систему и ОЗУ** | Фоновые службы приложения + Shizuku в памяти | **0% нагрузки**: отработал за 1 секунду при загрузке и уснул |
| **Устойчивость к сбоям / OOM** | Служба может выгружаться системой или сбиваться | 100% отказоустойчивость (применяется на этапе ядра `post-fs-data`) |
| **Работа без Root** | ✅ Возможна через Shizuku (только базовый CarrierConfig) | ❌ Требуется Root (для монтирования в раздел модема) |

### Главное техническое отличие:
`Pixel-IMS-5G` (barrylk) правит только операторскую таблицу `cfg.db`. Однако если модем не имеет разрешения на уровне `uecap`, физическое радиоядро Shannon 5300 не задействует частоты n79 и урезанные комбинации агрегации. Наш модуль закрывает этот пробел, заменяя и базу операторов, и карту возможностей радиомодема.

---

## 📊 Верификация работы (Системные дампы)

### 1. Агрегация трёх несущих частот (LTE-A 3CA на Билайн):
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
*Суммарная ширина полосы: 40 МГц (15 МГц B3 + 15 МГц B7 + 10 МГц B20). `isUsingCarrierAggregation = true`.*

### 2. Регистрация IMS-сервисов (VoLTE / VoWiFi на двух SIM):
```
ImsRegistrationController:
  [0] subId=1 (MegaFon) -> Registered over IWLAN (Wi-Fi Calling) / VoLTE Active (EVS-SWB)
  [1] subId=2 (Beeline) -> Registered over IWLAN (Wi-Fi Calling) / VoLTE Active (AMR-WB)
```

### 3. Активные параметры 5G в дампе телефонии:
```
carrier_nr_availabilities_int_array = [1, 2]
additional_nr_advanced_bands_int_array = [1, 3, 8, 28, 41, 78, 79]
vonr_enabled_bool = true
```

---

## 📥 Установка

1. Скачайте релизный архив [`Pixel_8_Pro_RU_5G_VoLTE_Fix.zip`](./Pixel_8_Pro_RU_5G_VoLTE_Fix.zip).
2. Откройте менеджер рут-прав (**KernelSU**, **Magisk** или **APatch**).
3. Перейдите в раздел **Модули** ➔ **Установить из хранилища**.
4. Выберите архив и дождитесь завершения установки.
5. Перезагрузите устройство.

---

## 📁 Структура модуля

```
├── Pixel_8_Pro_RU_5G_VoLTE_Fix.zip  # Готовый архив для установки
├── module.prop                      # Метаданные модуля
├── customize.sh                     # Скрипт установки прав доступа
├── post-fs-data.sh                  # Ранний bind-mount баз модема в /mnt/vendor/modem_img
├── service.sh                       # Однократный запуск Applier.dex при загрузке
├── config.json                      # Базовые параметры CarrierConfig
├── confpack/
│   └── cfg.db                       # База модема Shannon с привязкой операторов РФ
├── uecap/
│   └── WILDCARD.binarypb            # Разблокированный стек возможностей модема (n79 + CA)
└── system/
    └── bin/
        └── Applier.dex              # Скомпилированный DEX-мост к ICarrierConfigLoader
```

---

## ⚖️ Лицензия
MIT License. Проект разработан для адаптации устройств линейки Google Pixel под региональные стандарты связи.
