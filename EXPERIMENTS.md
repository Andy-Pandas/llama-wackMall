# История экспериментов с производительностью

Железо: RTX 3070 8GB (sm_86), Xeon E5-2680 v4 (AVX2), 62GB DDR4, PCIe 3.0 x16
Модель: Qwen3.6-35B-A3B (архитектура qwen35moe, MoE 256 экспертов/слой)

## 2026-11-09: Переход на PolyStrata

### Контекст
Раньше вызывали через llama.cpp (форк llama-wackMall). Медленно. Решили
попробовать PolyStrata (форк Strata), который специально оптимизирован под
Qwen3.6-35B-A3B на 8GB VRAM.

### Установка
- Склонирован VecSzn/PolyStrata в `~/exp/PolyStrata`
- Движок `strata-poly` скомпилирован (или готовый для sm_86)
- Модель не скачивали новую: использовали имеющийся `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`
  через `--custom-gguf` (файл распознан как qwen35moe, совместим)
- setup нашёл её, подготовил pack, создал `run-qwen36...sh`
- reasoning выключили: `"reasoning_effort": "none"` в config json

### Скорость (PolyStrata, model UD-Q4_K_XL, ctx 32k, reasoning none)
| Метрика | Значение |
|---|---|
| Генерация (короткий промпт) | ~70-77 t/s |
| Генерация (длинный промпт 1800 ток) | ~71-75 t/s |
| Чтение (промпт 1810 ток) | ~727-731 t/s |
| Загрузка модели | 1.4-9.8 s |
| Эксперты в VRAM | 2079-2113 из 10240 (3.7-3.8 GiB) |

### Сравнение с llama.cpp (та же модель, до перехода)
| Метрика | llama.cpp | PolyStrata |
|---|---|---|
| Генерация | ~16 t/s | ~70 t/s (4.4x) |
| Чтение | ~100 t/s | ~730 t/s (7x) |
| Загрузка | 2-3 мин | ~2-10 s |

### Запуск/управление
- `~/exp/PolyStrata/strata.sh` (алиас `strata`): start/stop/status/log/list
- порт 8080, API OpenAI `/v1` (такой же как llama.cpp)
- Pi подключается через провайдер `local-llama` (models.json), PolyStrata
  принимает любой id модели

## 2026-11-09: llama.cpp - оптимизации

### Данные из бенчмарка b11540 (llama.cpp vs PolyStrata на 8GB ноутбуке)
- llama.cpp tuned: `-ngl 99 --n-cpu-moe 30 -c 36864 -ctk q8_0 -ctv q8_0 -fa on -t 20 -ub 512`
  + MTP draft (`--spec-type draft-mtp --spec-draft-n-max 2`)
- на 8GB ноутбуке llama.cpp давал 44 t/s, PolyStrata 80 t/s

### Что применили к run.sh llama.cpp
- `-t 20` (было 12), `-ub 512` (было 1024) — контекст 128k сохранили
- MTP draft **не работает**: модель UD-Q4_K_XL НЕ содержит MTP-слоёв
  (`nextn_predict_layers` только в метаданных, весов нет). Убрали.
- Результат: llama.cpp ~19 t/s генерация (было 3.3 через роутер, 16 без тюнинга)

### Вывод
PolyStrata существенно быстрее llama.cpp на этом железе. llama.cpp оставлен
как запасной вариант (оптимизирован, но 3.7x медленнее).

## Планы
- [ ] Доскачать Qwen3.6-35B-A3B UD-Q3_K_M (17.1 GB) - для 8GB карты быстрее
- [ ] Протестировать Q3_K_M с контекстом 128k
- [ ] Проверить Pi с PolyStrata (MCP/grammar работает)
