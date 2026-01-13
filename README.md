# Recordatorios y Control

Aplicación móvil desarrollada en **Flutter** con **Firebase**. Permite crear y gestionar recordatorios (con recurrencia), recibir notificaciones programadas y supervisar usuarios.

---

## 📌 Descripción

**Recordatorios y Control** es una app para gestionar recordatorios personales y permitir la supervisión entre usuarios permitiendo ver los recordatorios de otra persona gracias a un **codigo de supervision** de 6 digitos que se encontrará en el perfil y permitiendo poner notificaciones para comprobar si se realizan las tareas de esos usuarios. Incluye notificaciones programadasy recurrencia en recordatorios.

---

## ✨ Características principales

- Autenticación: Email/Password y Google Sign-In.

- CRUD de recordatorios (crear, editar, borrar, ver).

- Recurrencia: sin repetición, diaria, semanal, cada X días.

- Notificaciones locales programadas (Workmanager + flutter_local_notifications).

- Supervisión: ver recordatorios de usuarios supervisados y opciones de notificación por supervisor.

- Recordatorios agrupados en la UI por día con cabeceras.

- Soporte multi-idioma (español / inglés) y formateo de fechas con intl.

- Almacenamiento de fotos en Firebase Storage.

- Eliminación segura de cuenta: borrado batched de recordatorios, limpieza de relaciones y borrado de Storage.

---

## 🧰 Tecnologías

- **Flutter (Dart)**

- **Firebase**: Auth, Firestore, Storage

- Paquetes: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `google_sign_in`, `workmanager`, `flutter_local_notifications`, `intl`, etc.

---

## ⚙️ Requisitos

Flutter SDK (usa la versión indicada en pubspec.yaml)

Cuenta de Firebase (proyecto Android registrado para pruebas locales)

Android Studio / dispositivo Android o emulador (en caso de solo querer ejecutar la aplicacion en un dispositivo android, descargar
la apk generada en [este enlace](https://github.com/AlejandroLaredo005/Recordatorios-Y-Control/releases/tag/v1.0.0))

### Instrucciones de instalación
1. En el dispositivo Android, activar **Instalar aplicaciones de orígenes desconocidos** (según versión Android).  
2. Descargar la APK desde el enlace anterior.  
3. Abrir el archivo descargado y aceptar la instalación. 

---

## IMPORTANTE

**Los archivos de configuración de Firebase no están incluidos en este repositorio público.**  se han ocultado archivos como
`lib/firebase_options.dart` y `android/app/google-services.json`.

---

## ▶️ Ejecutar desde código (desarrollo)

Clona el repositorio y ejecuta localmente:

```bash
git clone https://github.com/AlejandroLaredo005/Recordatorios-Y-Control.git
cd recordatorios-y-control
flutter pub get
