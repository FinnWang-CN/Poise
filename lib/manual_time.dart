/// Only manual creation/editing uses this guard. Imported source timestamps are retained.
String? manualTimeError(DateTime measurement, DateTime now) =>
    measurement.isAfter(now) ? '测量时间不能晚于现在，请调整日期或时间' : null;
