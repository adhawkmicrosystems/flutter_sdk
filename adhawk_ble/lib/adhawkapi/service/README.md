## Stream Data

The following streams are enabled at 60Hz:

| Stream            | Format    | Size (B)  |
|:------------------|:--------  |:--------- |
| Gaze              | 4f        | 16        |
| Eye Center        | 6f        | 24        |
| Pupil Diameter    | 2f        | 8         |
| IMU Quaternion    | 4f        | 16        |
| ET packet header  | QB (4)B   | 13        |
| DB upload header  | IQ        | 12        |

| Link      | Packet Size | Data Rate (ET at 60Hz)  |
|:----------|:------------|:------------------------|
| Bluetooth | 77 bytes    | 4.6 KB/s                |
| Upload    | 89 bytes    | 320.4 KB/min            |

## Events

The following events are enabled. The rates are approximated

| Stream            | Format    | Size (B)  | ~Rate (Hz)    | Total |
|:------------------|:--------  |:--------- | :-------------|:------|
| Blinks            | 2f        | 8         | 0.33          | 2.64  |
| Saccade           | 5f        | 20        | 3             | 60    |
| Saccade Start     | fB        | 5         | 3             | 15    |
| Saccade End       | fB4f      | 21        | 3             | 63    |
| Trackloss Start   | fB        | 5         | 0             | 0     |
| Trackloss End     | fB        | 5         | 0             | 0     |

| Link      | Data Rate                 |
|:----------|:--------------------------|
| BlueTooth | 141 B/s                   |
| Upload    | 15 KB/min                 |

We publish approximately 335 KB/min
