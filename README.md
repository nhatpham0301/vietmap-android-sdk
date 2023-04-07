# Vietmap GL Native

# Cài đặt  Android SDK
Để có thể phát triển ứng dụng của bạn với VietMap SDK thì bạn cần cài đặt dependency của nó
Hãy bật ProGuard cho ứng dụng của bạn nếu bị lỗi vượt quá giới hạn 65k method,
## 1. Thêm dependency
* Mở Android Studio
* Mở file build.gradle của ứng dụng
* Đảm bảo minSdkVersion tối thiểu 21 trở lên
* Thêm các dòng sau vào trong file build.gradle
``` java

dependencies {
    ...
    implementation 'org.maplibre.gl:android-sdk-geojson:5.9.0'
    implementation 'com.squareup.okhttp3:okhttp:3.12.7'
}
```