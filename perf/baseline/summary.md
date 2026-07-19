
### tiny

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 23.2±0.8ms | 13.5±1.9ms | 0.6x | 25ms | 14ms | 0.6x | -7.3% | 2.4 | CHECK |
| c | 14.9±0.5ms | 11.8±0.4ms | 0.8x | 16ms | 14ms | 0.9x | -6.6% | 2.3 | CHECK |
| cpp | 125.6±1.8ms | 14.4±0.6ms | 0.1x | 131ms | 15ms | 0.1x | -4.1% | 3.0 | noise |
| css | 5.4±0.4ms | 16.9±0.5ms | 3.1x | 6ms | 19ms | 3.2x | -10.3% | 1.7 | noise |
| go | 7.3±0.6ms | 10.9±0.5ms | 1.5x | 7ms | 13ms | 1.9x | +4.6% | 0.6 | noise |
| html | 5.5±0.4ms | 10.7±0.3ms | 2.0x | 6ms | 12ms | 2.0x | -9.0% | 1.2 | noise |
| javascript | 30.0±0.6ms | 14.4±0.4ms | 0.5x | 31ms | 16ms | 0.5x | -3.3% | 1.7 | noise |
| json | 5.0±0.4ms | 10.2±0.2ms | 2.0x | 6ms | 11ms | 1.8x | -16.0% | 2.3 | CHECK |
| lua | 6.7±0.9ms | 12.1±0.4ms | 1.8x | 8ms | 12ms | 1.5x | -16.0% | 1.5 | noise |
| markdown | 10.6±0.4ms | 14.5±0.4ms | 1.4x | 12ms | 17ms | 1.4x | -11.3% | 3.4 | CHECK |
| python | 27.4±1.0ms | 12.9±0.2ms | 0.5x | 29ms | 14ms | 0.5x | -5.5% | 1.6 | noise |
| ruby | 46.9±0.9ms | 13.1±0.5ms | 0.3x | 49ms | 16ms | 0.3x | -4.4% | 2.5 | noise |
| rust | 33.6±0.7ms | 13.4±0.2ms | 0.4x | 36ms | 14ms | 0.4x | -6.6% | 3.4 | CHECK |
| swift | 72.1±1.0ms | 11.5±0.3ms | 0.2x | 75ms | 12ms | 0.2x | -3.9% | 2.8 | noise |
| tsx | 62.3±1.5ms | 21.7±0.5ms | 0.3x | 66ms | 23ms | 0.3x | -5.6% | 2.6 | CHECK |
| typescript | 49.0±0.8ms | 24.3±2.0ms | 0.5x | 51ms | 24ms | 0.5x | -4.0% | 2.6 | noise |
| yaml | 9.9±0.4ms | 11.7±2.2ms | 1.2x | 12ms | 12ms | 1.0x | -17.7% | 5.3 | CHECK |

avg ratio now: 1.0x (docs: 1.0x), CHECK rows: 7

### small

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 23.9±0.4ms | 18.9±0.4ms | 0.8x | 26ms | 20ms | 0.8x | -8.1% | 4.8 | CHECK |
| c | 16.2±0.6ms | 18.6±0.6ms | 1.1x | 17ms | 20ms | 1.2x | -4.6% | 1.4 | noise |
| cpp | 126.9±1.9ms | 26.8±0.6ms | 0.2x | 133ms | 30ms | 0.2x | -4.6% | 3.2 | noise |
| css | 5.9±0.4ms | 20.2±2.0ms | 3.4x | 7ms | 21ms | 3.0x | -15.3% | 2.5 | CHECK |
| go | 8.7±0.4ms | 20.4±0.3ms | 2.3x | 12ms | 23ms | 1.9x | -27.5% | 8.9 | CHECK |
| html | 9.8±0.6ms | 27.2±1.3ms | 2.8x | 11ms | 29ms | 2.6x | -10.5% | 2.0 | CHECK |
| javascript | 30.1±0.6ms | 17.0±0.3ms | 0.6x | 32ms | 20ms | 0.6x | -5.9% | 3.2 | CHECK |
| json | 5.9±0.8ms | 13.4±0.2ms | 2.3x | 7ms | 16ms | 2.3x | -15.7% | 1.5 | noise |
| lua | 8.2±0.3ms | 18.4±1.0ms | 2.2x | 9ms | 21ms | 2.3x | -8.5% | 2.7 | CHECK |
| markdown | 10.3±0.5ms | 16.2±0.3ms | 1.6x | 11ms | 18ms | 1.6x | -6.4% | 1.5 | noise |
| python | 27.9±0.8ms | 21.3±0.3ms | 0.8x | 30ms | 24ms | 0.8x | -7.0% | 2.7 | CHECK |
| ruby | 47.9±0.7ms | 22.7±0.2ms | 0.5x | 51ms | 25ms | 0.5x | -6.2% | 4.3 | CHECK |
| rust | 33.8±0.4ms | 17.4±0.3ms | 0.5x | 36ms | 19ms | 0.5x | -6.2% | 5.8 | CHECK |
| swift | 72.4±1.2ms | 17.9±1.1ms | 0.2x | 77ms | 20ms | 0.3x | -6.0% | 3.9 | CHECK |
| tsx | 62.7±0.6ms | 33.0±1.1ms | 0.5x | 67ms | 36ms | 0.5x | -6.5% | 7.4 | CHECK |
| typescript | 49.1±0.5ms | 32.3±0.5ms | 0.7x | 53ms | 34ms | 0.6x | -7.3% | 8.4 | CHECK |
| yaml | 10.2±0.4ms | 12.6±0.3ms | 1.2x | 13ms | 14ms | 1.1x | -21.9% | 6.6 | CHECK |

avg ratio now: 1.3x (docs: 1.2x), CHECK rows: 13

### medium

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 35.7±0.4ms | 81.7±1.1ms | 2.3x | 40ms | 88ms | 2.2x | -10.8% | 10.6 | CHECK |
| c | 28.3±0.6ms | 85.5±1.1ms | 3.0x | 30ms | 91ms | 3.0x | -5.7% | 3.0 | CHECK |
| cpp | 142.1±1.3ms | 149.2±3.0ms | 1.0x | 149ms | 155ms | 1.0x | -4.6% | 5.5 | noise |
| css | 10.3±0.4ms | 55.5±3.4ms | 5.4x | 11ms | 58ms | 5.3x | -6.2% | 1.9 | noise |
| go | 16.6±0.4ms | 74.0±1.7ms | 4.4x | 17ms | 77ms | 4.5x | -2.1% | 0.9 | noise |
| html | 36.1±0.9ms | 79.3±1.6ms | 2.2x | 37ms | 82ms | 2.2x | -2.4% | 1.0 | noise |
| javascript | 50.3±1.4ms | 168.7±1.8ms | 3.4x | 51ms | 172ms | 3.4x | -1.4% | 0.5 | noise |
| json | 12.4±0.6ms | 68.4±0.7ms | 5.5x | 13ms | 71ms | 5.5x | -4.8% | 1.1 | noise |
| lua | 23.5±0.6ms | 81.6±2.1ms | 3.5x | 24ms | 84ms | 3.5x | -2.0% | 0.8 | noise |
| markdown | 31.3±0.7ms | 118.6±0.8ms | 3.8x | 33ms | 122ms | 3.7x | -5.0% | 2.3 | CHECK |
| python | 39.6±0.5ms | 91.8±0.9ms | 2.3x | 42ms | 96ms | 2.3x | -5.7% | 4.6 | CHECK |
| ruby | 63.3±0.9ms | 111.1±1.2ms | 1.8x | 65ms | 115ms | 1.8x | -2.6% | 1.8 | noise |
| rust | 44.4±0.6ms | 83.8±0.6ms | 1.9x | 46ms | 86ms | 1.9x | -3.5% | 2.9 | noise |
| swift | 86.5±1.2ms | 97.5±1.2ms | 1.1x | 88ms | 99ms | 1.1x | -1.7% | 1.3 | noise |
| tsx | 68.9±1.1ms | 98.5±0.9ms | 1.4x | 71ms | 102ms | 1.4x | -3.0% | 1.9 | noise |
| typescript | 61.5±0.7ms | 193.1±2.3ms | 3.1x | 63ms | 198ms | 3.1x | -2.4% | 2.1 | noise |
| yaml | 19.9±0.4ms | 117.8±51.1ms | 5.9x | 22ms | 103ms | 4.7x | -9.5% | 5.2 | CHECK |

avg ratio now: 3.1x (docs: 3.0x), CHECK rows: 5

### large

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 62.2±1.0ms | 278.7±43.8ms | 4.5x | 66ms | 271ms | 4.1x | -5.7% | 3.8 | CHECK |
| c | 83.5±21.3ms | 357.6±6.1ms | 4.3x | 80ms | 372ms | 4.7x | +4.3% | 0.2 | noise |
| cpp | 281.2±2.5ms | 1188.3±8.5ms | 4.2x | 295ms | 1243ms | 4.2x | -4.7% | 5.6 | noise |
| css | 59.9±1.2ms | 199.2±2.4ms | 3.3x | 65ms | 211ms | 3.2x | -7.9% | 4.4 | CHECK |
| go | 394.5±3.7ms | 2390.1±19.4ms | 6.1x | 408ms | 2435ms | 6.0x | -3.3% | 3.7 | noise |
| html | 55.2±0.6ms | 82.1±1.2ms | 1.5x | 57ms | 84ms | 1.5x | -3.2% | 2.8 | noise |
| javascript | 92.1±1.1ms | 626.3±4.8ms | 6.8x | 94ms | 653ms | 6.9x | -2.0% | 1.7 | noise |
| json | 42.6±0.6ms | 350.4±2.5ms | 8.2x | 44ms | 357ms | 8.1x | -3.1% | 2.4 | noise |
| lua | 38.5±0.4ms | 181.7±1.7ms | 4.7x | 40ms | 186ms | 4.7x | -3.8% | 3.4 | noise |
| markdown | 82.1±1.8ms | 536.3±3.8ms | 6.5x | 85ms | 548ms | 6.4x | -3.4% | 1.6 | noise |
| python | 146.1±1.1ms | 702.3±2.6ms | 4.8x | 150ms | 715ms | 4.8x | -2.6% | 3.4 | noise |
| ruby | 75.2±0.8ms | 161.8±5.3ms | 2.2x | 77ms | 164ms | 2.1x | -2.4% | 2.3 | noise |
| rust | 66.0±1.0ms | 237.5±2.0ms | 3.6x | 67ms | 240ms | 3.6x | -1.5% | 1.1 | noise |
| swift | 109.3±1.4ms | 199.3±1.9ms | 1.8x | 111ms | 203ms | 1.8x | -1.5% | 1.2 | noise |
| tsx | 111.1±1.5ms | 570.0±3.1ms | 5.1x | 112ms | 577ms | 5.2x | -0.8% | 0.6 | noise |
| typescript | 482.0±2.9ms | 5876.8±37.4ms | 12.2x | 486ms | 5931ms | 12.2x | -0.8% | 1.4 | noise |
| yaml | 23.3±0.4ms | 163.9±1.8ms | 7.0x | 23ms | 165ms | 7.2x | +1.2% | 0.7 | noise |

avg ratio now: 5.1x (docs: 5.1x), CHECK rows: 2

### xlarge

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c | 1271.9±10.0ms | 7002.2±27.2ms | 5.5x | 1281ms | 7151ms | 5.6x | -0.7% | 0.9 | noise |
| javascript | 291.2±2.3ms | 2471.4±115.1ms | 8.5x | 307ms | 2593ms | 8.4x | -5.1% | 6.9 | CHECK |

avg ratio now: 7.0x (docs: 7.0x), CHECK rows: 1
