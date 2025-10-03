# flutter_timezone

A flutter plugin for getting the local timezone of the OS.

This is a fork of the original [flutter_native_timezone](https://pub.dev/packages/flutter_native_timezone) due to lack of maintenance of that package.

## Getting Started

Install this package and everything good will just follow along with you.

## Usage examples

### Get the timezone
```dart
final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
```

## Reference

[Wikipedia's list of TZ database names](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
