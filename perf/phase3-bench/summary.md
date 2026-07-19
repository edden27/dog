
### tiny

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 23.2±0.6ms | 14.6±6.8ms | 0.6x | 25ms | 14ms | 0.6x | -7.2% | 3.1 | CHECK |
| c | 14.8±0.5ms | 12.2±0.5ms | 0.8x | 16ms | 14ms | 0.9x | -7.7% | 2.4 | CHECK |
| cpp | 126.1±2.8ms | 13.8±0.3ms | 0.1x | 131ms | 15ms | 0.1x | -3.8% | 1.8 | noise |
| css | 5.3±0.4ms | 16.8±0.5ms | 3.2x | 6ms | 19ms | 3.2x | -12.5% | 2.0 | noise |
| go | 6.9±0.2ms | 10.6±0.3ms | 1.5x | 7ms | 13ms | 1.9x | -0.9% | 0.3 | noise |
| html | 5.4±0.3ms | 11.2±0.6ms | 2.1x | 6ms | 12ms | 2.0x | -9.7% | 1.8 | noise |
| javascript | 29.5±0.6ms | 14.5±0.3ms | 0.5x | 31ms | 16ms | 0.5x | -4.8% | 2.4 | noise |
| json | 4.9±0.2ms | 10.5±0.4ms | 2.1x | 6ms | 11ms | 1.8x | -18.4% | 5.5 | CHECK |
| lua | 6.5±0.3ms | 11.7±0.3ms | 1.8x | 8ms | 12ms | 1.5x | -18.2% | 4.8 | CHECK |
| markdown | 9.9±0.1ms | 14.2±0.2ms | 1.4x | 12ms | 17ms | 1.4x | -17.6% | 15.4 | CHECK |
| python | 26.1±0.4ms | 12.7±0.3ms | 0.5x | 29ms | 14ms | 0.5x | -9.8% | 6.3 | CHECK |
| ruby | 45.7±0.6ms | 12.9±0.2ms | 0.3x | 49ms | 16ms | 0.3x | -6.7% | 5.5 | CHECK |
| rust | 32.6±0.3ms | 13.2±0.2ms | 0.4x | 36ms | 14ms | 0.4x | -9.5% | 11.6 | CHECK |
| swift | 70.8±1.2ms | 12.0±1.9ms | 0.2x | 75ms | 12ms | 0.2x | -5.6% | 3.5 | CHECK |
| tsx | 61.7±1.5ms | 21.9±0.2ms | 0.4x | 66ms | 23ms | 0.3x | -6.5% | 2.9 | CHECK |
| typescript | 48.4±0.8ms | 23.8±0.3ms | 0.5x | 51ms | 24ms | 0.5x | -5.0% | 3.1 | CHECK |
| yaml | 9.5±0.2ms | 11.2±0.1ms | 1.2x | 12ms | 12ms | 1.0x | -20.5% | 10.4 | CHECK |

avg ratio now: 1.0x (docs: 1.0x), CHECK rows: 12

### small

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 23.0±0.8ms | 18.8±0.5ms | 0.8x | 26ms | 20ms | 0.8x | -11.4% | 3.6 | CHECK |
| c | 15.5±0.4ms | 18.3±0.3ms | 1.2x | 17ms | 20ms | 1.2x | -9.1% | 3.7 | CHECK |
| cpp | 127.9±1.8ms | 27.6±0.7ms | 0.2x | 133ms | 30ms | 0.2x | -3.8% | 2.9 | noise |
| css | 5.8±0.5ms | 20.2±0.7ms | 3.5x | 7ms | 21ms | 3.0x | -16.5% | 2.2 | CHECK |
| go | 8.2±0.6ms | 20.8±0.8ms | 2.6x | 12ms | 23ms | 1.9x | -32.0% | 6.0 | CHECK |
| html | 9.3±0.5ms | 27.1±0.8ms | 2.9x | 11ms | 29ms | 2.6x | -15.6% | 3.2 | CHECK |
| javascript | 30.9±1.0ms | 17.8±0.6ms | 0.6x | 32ms | 20ms | 0.6x | -3.3% | 1.0 | noise |
| json | 5.5±0.5ms | 13.8±0.5ms | 2.5x | 7ms | 16ms | 2.3x | -20.9% | 2.7 | CHECK |
| lua | 7.3±0.4ms | 18.2±1.0ms | 2.5x | 9ms | 21ms | 2.3x | -18.4% | 4.3 | CHECK |
| markdown | 9.9±0.3ms | 16.1±0.2ms | 1.6x | 11ms | 18ms | 1.6x | -9.9% | 3.1 | CHECK |
| python | 26.8±0.5ms | 21.4±0.2ms | 0.8x | 30ms | 24ms | 0.8x | -10.8% | 6.8 | CHECK |
| ruby | 46.3±0.5ms | 23.0±1.9ms | 0.5x | 51ms | 25ms | 0.5x | -9.3% | 8.8 | CHECK |
| rust | 33.4±0.5ms | 18.1±0.8ms | 0.5x | 36ms | 19ms | 0.5x | -7.2% | 5.3 | CHECK |
| swift | 71.1±1.0ms | 17.8±0.3ms | 0.2x | 77ms | 20ms | 0.3x | -7.6% | 5.7 | CHECK |
| tsx | 63.1±1.9ms | 32.8±0.9ms | 0.5x | 67ms | 36ms | 0.5x | -5.8% | 2.0 | noise |
| typescript | 49.0±0.9ms | 32.1±0.3ms | 0.7x | 53ms | 34ms | 0.6x | -7.6% | 4.6 | CHECK |
| yaml | 9.8±0.5ms | 12.4±0.2ms | 1.3x | 13ms | 14ms | 1.1x | -24.7% | 5.9 | CHECK |

avg ratio now: 1.3x (docs: 1.2x), CHECK rows: 14

### medium

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 28.6±0.7ms | 84.3±1.7ms | 2.9x | 40ms | 88ms | 2.2x | -28.4% | 17.3 | CHECK |
| c | 21.2±0.5ms | 88.2±2.4ms | 4.2x | 30ms | 91ms | 3.0x | -29.5% | 16.4 | CHECK |
| cpp | 131.1±2.0ms | 148.7±1.7ms | 1.1x | 149ms | 155ms | 1.0x | -12.0% | 9.0 | CHECK |
| css | 9.7±0.4ms | 54.7±0.9ms | 5.7x | 11ms | 58ms | 5.3x | -12.1% | 3.0 | CHECK |
| go | 13.9±0.4ms | 73.0±0.9ms | 5.2x | 17ms | 77ms | 4.5x | -18.1% | 7.3 | CHECK |
| html | 31.3±0.4ms | 78.8±1.4ms | 2.5x | 37ms | 82ms | 2.2x | -15.3% | 12.6 | CHECK |
| javascript | 40.6±0.6ms | 164.6±2.5ms | 4.1x | 51ms | 172ms | 3.4x | -20.3% | 17.1 | CHECK |
| json | 11.2±0.4ms | 68.1±0.8ms | 6.1x | 13ms | 71ms | 5.5x | -14.0% | 4.4 | CHECK |
| lua | 20.2±0.3ms | 79.9±1.7ms | 4.0x | 24ms | 84ms | 3.5x | -15.8% | 11.2 | CHECK |
| markdown | 24.1±0.4ms | 118.1±2.4ms | 4.9x | 33ms | 122ms | 3.7x | -26.9% | 21.1 | CHECK |
| python | 33.8±0.8ms | 91.4±6.3ms | 2.7x | 42ms | 96ms | 2.3x | -19.6% | 10.3 | CHECK |
| ruby | 53.7±0.5ms | 108.6±0.9ms | 2.0x | 65ms | 115ms | 1.8x | -17.4% | 24.9 | CHECK |
| rust | 38.7±0.4ms | 82.4±2.0ms | 2.1x | 46ms | 86ms | 1.9x | -15.8% | 17.3 | CHECK |
| swift | 75.9±0.5ms | 94.7±1.0ms | 1.2x | 88ms | 99ms | 1.1x | -13.8% | 24.4 | CHECK |
| tsx | 65.0±0.4ms | 96.7±0.7ms | 1.5x | 71ms | 102ms | 1.4x | -8.4% | 14.0 | CHECK |
| typescript | 54.8±0.3ms | 192.7±17.1ms | 3.5x | 63ms | 198ms | 3.1x | -12.9% | 25.1 | CHECK |
| yaml | 14.4±0.4ms | 108.9±37.3ms | 7.6x | 22ms | 103ms | 4.7x | -34.6% | 19.6 | CHECK |

avg ratio now: 3.6x (docs: 3.0x), CHECK rows: 17

### large

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bash | 42.9±0.8ms | 265.3±3.0ms | 6.2x | 66ms | 271ms | 4.1x | -35.1% | 28.3 | CHECK |
| c | 62.2±0.5ms | 355.1±2.3ms | 5.7x | 80ms | 372ms | 4.7x | -22.3% | 34.9 | CHECK |
| cpp | 185.9±1.3ms | 1194.5±7.3ms | 6.4x | 295ms | 1243ms | 4.2x | -37.0% | 84.5 | CHECK |
| css | 53.4±0.4ms | 199.7±2.2ms | 3.7x | 65ms | 211ms | 3.2x | -17.9% | 26.7 | CHECK |
| go | 355.2±3.7ms | 2391.5±15.7ms | 6.7x | 408ms | 2435ms | 6.0x | -13.0% | 14.2 | CHECK |
| html | 48.5±0.4ms | 80.0±0.7ms | 1.7x | 57ms | 84ms | 1.5x | -15.0% | 19.3 | CHECK |
| javascript | 64.9±0.4ms | 640.7±63.9ms | 9.9x | 94ms | 653ms | 6.9x | -30.9% | 65.0 | CHECK |
| json | 38.1±0.3ms | 349.6±3.7ms | 9.2x | 44ms | 357ms | 8.1x | -13.3% | 22.6 | CHECK |
| lua | 34.5±0.4ms | 181.1±1.5ms | 5.3x | 40ms | 186ms | 4.7x | -13.9% | 13.6 | CHECK |
| markdown | 69.3±0.4ms | 536.5±1.9ms | 7.7x | 85ms | 548ms | 6.4x | -18.5% | 36.9 | CHECK |
| python | 115.6±0.7ms | 702.5±3.9ms | 6.1x | 150ms | 715ms | 4.8x | -22.9% | 48.2 | CHECK |
| ruby | 60.4±0.5ms | 159.6±0.9ms | 2.6x | 77ms | 164ms | 2.1x | -21.5% | 32.3 | CHECK |
| rust | 50.6±0.7ms | 234.6±1.0ms | 4.6x | 67ms | 240ms | 3.6x | -24.4% | 24.8 | CHECK |
| swift | 84.2±0.9ms | 200.2±11.9ms | 2.4x | 111ms | 203ms | 1.8x | -24.1% | 28.7 | CHECK |
| tsx | 88.4±0.6ms | 565.1±2.9ms | 6.4x | 112ms | 577ms | 5.2x | -21.0% | 38.7 | CHECK |
| typescript | 402.2±1.9ms | 5858.9±88.0ms | 14.6x | 486ms | 5931ms | 12.2x | -17.2% | 45.1 | CHECK |
| yaml | 17.3±0.2ms | 178.5±68.7ms | 10.3x | 23ms | 165ms | 7.2x | -24.8% | 27.9 | CHECK |

avg ratio now: 6.4x (docs: 5.1x), CHECK rows: 17

### xlarge

| language | dog now | bat now | ratio now | dog docs | bat docs | ratio docs | dog delta | sigma | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c | 1177.4±7.5ms | 7000.6±133.0ms | 5.9x | 1281ms | 7151ms | 5.6x | -8.1% | 13.7 | CHECK |
| javascript | 247.7±2.4ms | 2435.7±10.3ms | 9.8x | 307ms | 2593ms | 8.4x | -19.3% | 24.3 | CHECK |

avg ratio now: 7.9x (docs: 7.0x), CHECK rows: 2
