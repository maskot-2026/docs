# INFORME DE ACTIVIDADES

**Proyecto:** +KOT  
**Contrato:** 1493-PROINNOVATE-EIN-2025  
**Código del Proyecto:** EIN-4-P-612-25  
**Convocatoria:** Emprendimientos Innovadores – Startup Perú  
**Entidad Ejecutora:** Wagner Brando Romañol Tuanama (RUC: 10612664868)  
**Periodo evaluado:** 02/12/2025 al 01/07/2026  
**Hito reportado:** Hito 1 – Arquitectura, plataforma pública y e-commerce  
**Profesional reportado:** [Nombre completo]

---

## 1. OBJETIVO DE LAS ACTIVIDADES

Diseñar la arquitectura técnica del proyecto +KOT y desarrollar la primera fase de la plataforma web: las páginas públicas de marketing, el catálogo de productos, el carrito de compras, el flujo de checkout con integración de Mercado Pago y el módulo completo de cuenta de usuario. Esta fase cubre el recorrido del cliente desde el primer contacto con la marca hasta la finalización de una compra, sentando las bases del Producto Mínimo Viable (MVP) del negocio.

---

## 2. ACTIVIDADES REALIZADAS

### 2.1 Diseño de arquitectura y configuración del entorno

- Definición y configuración de la arquitectura técnica del proyecto: frontend en React 19 con TypeScript y Vite, backend gestionado mediante Supabase (PostgreSQL con Row-Level Security y funciones RPC), API de integración en FastAPI (Python, patrón DDD) para gestión de pagos, identidad y soporte.
- Configuración de entornos de desarrollo, staging y producción con variables de entorno seguras y estructura modular por features.
- Diseño del modelo relacional de base de datos: 7 módulos SQL con tablas de identidad, e-commerce, checkout/suscripciones, legal, administración, usuarios y directorio de especialistas.
- Implementación de políticas de seguridad Row-Level Security (RLS) en todas las tablas y funciones RPC tipadas por rol (`user`, `professional`, `admin`).

### 2.2 Módulo de Marketing y Contenido Público (Módulo 1)

- Desarrollo de la página **Landing Home** con secciones configurables desde CMS: Hero, Propuesta de Valor, "Cómo Funciona", Trust, Sponsors/Aliados, Productos Destacados, Testimonios, FAQ reducida, Calculadora de Ahorro y CTA Banner final. Incluye loading skeleton y enlace directo al catálogo.
- Desarrollo de la página **Nosotros** con Hero, Misión y Visión, Timeline de hitos, Cards del equipo, Certificaciones y CTA Banner. Todo el contenido es editable por el administrador sin intervención de desarrollo.
- Desarrollo de la página **Preguntas Frecuentes (FAQ)** con listado de categorías, accordion de preguntas/respuestas por categoría y filtro de navegación.
- Desarrollo del **Blog** con listado de posts (imagen, categoría, título y resumen), artículo principal destacado (`is_main`), filtro por categoría y página de detalle con contenido en formato Markdown.

### 2.3 Módulo de Tienda y Catálogo (Módulo 2)

- Desarrollo del **Catálogo de Productos** con grid de productos, filtros por categoría, ordenamiento por popularidad y precio, indicador visual de descuento de suscripción y badge de producto para profesionales (`is_professional_product`).
- Desarrollo de la **Ficha de Producto** con galería de imágenes, selector de variantes (peso/presentación), precio dinámico por variante, toggle de compra única vs. suscripción con porcentaje de descuento visible, selector de frecuencia de suscripción (semanal / quincenal / mensual), tabla nutricional, lista de ingredientes con porcentaje y origen, reseñas de usuarios con rating promedio calculado y breadcrumb de navegación.

### 2.4 Módulo de Carrito de Compras (Módulo 3)

- Desarrollo del **Carrito de Compras** con lista de items (imagen, nombre, variante, cantidad, precio), modificación de cantidades respetando stock, eliminación de items, toggle compra única / suscripción por item, resumen con subtotal, descuentos, costo de envío desglosado e IGV 18% (base imponible + impuesto), cálculo dinámico de envío por distrito, input de cupón con validación en tiempo real, mensajes de error de cupón (mínimo de orden, vigencia), persistencia en `localStorage` para invitados y en base de datos para usuarios autenticados, y botón "Proceder al checkout".

### 2.5 Módulo de Checkout y Pagos (Módulo 4)

- Desarrollo del **Flujo de Checkout** en página única con tres secciones: Datos de facturación, Dirección de envío y Método de pago. Incluye autorrellenado de datos para usuarios autenticados, opción de agregar nueva dirección o perfil de facturación inline, selector de método de envío con costo y días estimados, e integración con **Mercado Pago Checkout Bricks** (tarjeta de crédito y débito). Soporte de compra como invitado sin registro.
- Desarrollo de la **Página de Confirmación de Orden** con número de orden y estado, fecha y hora, resumen de items, desglose de totales (subtotal, descuento, envío, IGV, total), snapshot de datos de envío y facturación, y enlace al historial de pedidos.
- Implementación del **flujo MIT (Merchant Initiated Transactions)** en la API de integración: tokenización de tarjetas vía Mercado Pago Vault, webhook de reconciliación de pagos, y endpoint de renovaciones automáticas (`cron-renewals`) ejecutado por `pg_cron` para suscripciones recurrentes.

### 2.6 Módulo de Cuenta de Usuario (Módulo 5)

- Desarrollo del módulo completo de **Autenticación**: registro con email/contraseña y validación de `username` único (`[a-z0-9_]`, 3–30 caracteres), registro y login con Google OAuth, recuperación de contraseña por email (magic link), verificación de email post-registro, trigger automático de creación de perfil y asignación de rol `user`, y redireccionamiento por rol al ingresar.
- Desarrollo de la **Página de Perfil Personal** con edición de nombre completo, username con validación de unicidad, subida y preview de foto de perfil (avatar vía Cloudinary), y acceso a datos de documento desde la pestaña de facturación.
- Desarrollo del **Gestor de Direcciones de Envío** (`AddressManager`): listado, agregar, editar, marcar como predeterminada y eliminar direcciones, con validación de afectación a suscripciones activas.
- Desarrollo del **Gestor de Perfiles de Facturación** (`BillingManager`): listado, crear, editar, marcar como predeterminado y eliminar perfiles con tipo de documento (DNI / CE / RUC), nombre legal y dirección.

---

## 3. RESULTADOS OBTENIDOS

- **Arquitectura técnica definida e implementada**: stack React 19 + TypeScript + Supabase + FastAPI (Python DDD), con modelo relacional de 7 módulos SQL, Row-Level Security en todas las tablas, funciones RPC tipadas por rol y estructura modular por features en el frontend.
- **Plataforma pública funcional** (Módulo 1): landing page, página Nosotros, FAQ y Blog, todos con contenido gestionable dinámicamente por el administrador sin intervención de desarrollo.
- **E-commerce operativo** (Módulos 2 y 3): catálogo de productos con variantes, filtros y reseñas; ficha de producto con tabla nutricional e ingredientes; carrito de compras persistente para invitados y usuarios autenticados con desglose de IGV y validación de cupones en tiempo real.
- **Flujo de compra completo** (Módulo 4): checkout en página única con Mercado Pago Checkout Bricks, soporte para invitados y usuarios autenticados, página de confirmación con snapshot de la orden, y API de pagos MIT con tokenización vía Mercado Pago Vault y renovaciones automáticas por `pg_cron`.
- **Sistema de cuenta de usuario completo** (Módulo 5): autenticación con email/contraseña y Google OAuth, gestión de perfil con avatar (Cloudinary), múltiples direcciones de envío y perfiles de facturación reutilizables.

---

## 4. DECLARACIÓN

Declaro que las actividades descritas han sido realizadas de manera efectiva durante el periodo señalado y en el marco del proyecto indicado.

---

<br>

**PROFESIONAL**  
[Nombre completo]  
DNI: [________]

<br><br>

---

**COORDINADOR GENERAL DEL PROYECTO**  
Wagner Brando Romañol Tuanama  
DNI: 61266486
