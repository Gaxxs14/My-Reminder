# Documentación de Arquitectura y Especificación de Proyecto
## Proyecto: Agenda Personal Inteligente con Asistente de Voz (My-Reminder)

Este documento detalla la especificación de diseño, la estructura del código en Clean Architecture y la seguridad robusta del sistema de recordatorios móviles con asistente de voz integrado.

---

## 1. Estructura y Organización del Código (Clean Architecture)

Adoptamos una arquitectura modular y limpia tanto en el móvil (Flutter) como en el servidor (C#) para garantizar la escalabilidad y mantenibilidad del proyecto a largo plazo.

### A. Estructura del Frontend (Flutter)
Ubicación: `/frontend`

Seguimos una organización basada en **características (features)** y capas limpias:

```text
frontend/lib/
├── core/                        # Configuración e infraestructura compartida
│   ├── network/                 # Cliente HTTP (Dio) e interceptores
│   ├── security/                # Manejo de tokens y biometría
│   ├── theme/                   # Paleta de colores premium y tipografías
│   └── utils/                   # Clases utilitarias y formateadores
│
├── features/                    # Módulos independientes de la aplicación
│   ├── auth/                    # Gestión de usuarios (Login, Registro)
│   │   ├── data/                # Repositorios y modelos de datos
│   │   ├── domain/              # Casos de uso (Lógica de negocio pura)
│   │   └── presentation/        # Pantallas, widgets y controladores de estado (UI)
│   │
│   ├── reminders/               # Gestión de recordatorios (Calendario, Tareas)
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── assistant/               # Interfaz del chat y asistente de voz
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── main.dart                    # Punto de entrada de la aplicación
```

### B. Estructura del Backend (C# .NET 10)
Ubicación: `/backend`

El backend se organiza en una solución de Visual Studio (`MyReminder.sln`) con 4 proyectos distintos siguiendo los principios de la Clean Architecture:

```text
backend/src/
├── MyReminder.API/              # Proyecto Web API (Controladores, Endpoints, Configuración JWT, Swagger)
├── MyReminder.Application/      # Interfaces de servicios, DTOs, Casos de Uso y validaciones
├── MyReminder.Domain/           # Entidades core del negocio (User, Reminder, Category) sin dependencias externas
└── MyReminder.Infrastructure/   # Conexión a base de datos (EF Core, PostgreSQL), encriptación BCrypt, cliente de Gemini
```

---

## 2. Modelo de Seguridad y Privacidad

El sistema implementa una seguridad moderna y robusta, equilibrando la protección de datos con la funcionalidad de Inteligencia Artificial:

1.  **Cifrado en Tránsito:** Toda la comunicación entre la aplicación móvil y la API se realiza a través de canales seguros **HTTPS/TLS**.
2.  **Autenticación de Usuarios:**
    *   **Contraseñas en el Servidor:** Se almacenan aplicando hashing mediante el algoritmo **BCrypt** con factor de coste alto.
    *   **Sesión Móvil:** Validación mediante tokens **JWT (JSON Web Tokens)** firmados digitalmente.
3.  **Seguridad en el Dispositivo (Móvil):**
    *   **Acceso a la App:** Integración biométrica (huella dactilar/rostro) usando la API nativa del teléfono a través del paquete `local_auth`.
    *   **Almacenamiento Seguro:** Las credenciales y el token JWT se guardan en el almacenamiento seguro del hardware del celular usando `flutter_secure_storage`.
4.  **Procesamiento de Datos para IA (Privacidad Funcional):**
    *   A diferencia de un gestor de contraseñas, los recordatorios no se encriptan de forma ilegible para el servidor (*Zero-Knowledge*). Esto es indispensable para que el backend pueda suministrar los textos de tus compromisos a la API de **Gemini** y permitir al Asistente de Voz comprender, buscar y programar eventos de forma inteligente.
    *   Las conexiones a la base de datos PostgreSQL en la nube (Neon) y a la API de Gemini viajan 100% encriptadas y protegidas por credenciales seguras.

---

## 3. Pila Tecnológica e Infraestructura en la Nube (100% Gratis)

*   **Base de Datos Relacional:** **Neon** (`neon.tech`) - *Plan Gratis*. Hospedaje administrado de PostgreSQL.
*   **Hospedaje del Backend:** **Koyeb** o **Render** - *Plan Gratis*.
    *   El backend en C# se empaquetará en un contenedor **Docker** optimizado.
    *   Koyeb ofrece tiempos de reactivación más rápidos en su plan gratuito en comparación con Render.
*   **Asistente de Voz (IA):** **Google AI Studio (Gemini 1.5 Flash)** - *Capa Gratis*. Procesa el lenguaje natural del usuario.
*   **Notificaciones Push:** **Firebase Cloud Messaging (FCM)**.
*   **Repositorio & CI/CD:** **GitHub**. Al hacer `git push` a la rama `main` en GitHub, el servidor en la nube compilará y actualizará el contenedor Docker de forma automática.

---

## 4. Hoja de Ruta del Desarrollo (Plan de Acción)

*   **Fase 1: Inicialización de Estructuras e Integración Git**
    *   Crear directorios físicos `/frontend` y `/backend`.
    *   Iniciar proyecto Flutter con la estructura Clean Architecture.
    *   Iniciar solución C# .NET 10 y sus 4 proyectos con Dockerfile.
    *   Enlazar las carpetas a los repositorios de GitHub correspondientes.
*   **Fase 2: Interfaz Móvil y Almacenamiento Local**
    *   Crear pantallas de autenticación, agenda y asistente de voz en Flutter.
    *   Configurar base de datos SQLite con `drift` en el móvil.
    *   Configurar notificaciones de alarmas locales.
*   **Fase 3: API REST C# y Base de Datos**
    *   Estructurar el backend y conectar a Postgres en Neon.tech.
    *   Desarrollar autenticación JWT.
*   **Fase 4: El Cerebro de IA y Voz**
    *   Integrar micrófono (STT) y sintetizador de voz (TTS) en Flutter.
    *   Conectar el backend de C# con Gemini API.
*   **Fase 5: Despliegue Cloud y Notificaciones Push**
    *   Subir contenedor Docker a la nube (Koyeb/Render).
    *   Configurar Firebase para alertas instantáneas.
