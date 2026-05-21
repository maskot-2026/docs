# INFORME DE ACTIVIDADES

**Proyecto:** +KOT  
**Contrato:** 1493-PROINNOVATE-EIN-2025  
**Código del Proyecto:** EIN-4-P-612-25  
**Convocatoria:** Emprendimientos Innovadores – Startup Perú  
**Entidad Ejecutora:** Wagner Brando Romañol Tuanama (RUC: 10612664868)  
**Periodo evaluado:** 02/12/2025 al 01/07/2026  
**Hito reportado:** Hito 2 – Panel de administración, compliance y funcionalidades avanzadas  
**Profesional reportado:** [Nombre completo]

---

## 1. OBJETIVO DE LAS ACTIVIDADES

Desarrollar la segunda fase de la plataforma web del proyecto +KOT: el historial de pedidos del usuario, el módulo de legal y compliance (conforme a Ley N.° 29733 e INDECOPI), el panel de administración completo con CMS de contenido, gestión de inventario y operaciones de back-office (pedidos, usuarios, cupones, reportes y reclamos), y la infraestructura del directorio de especialistas. Esta fase habilita la operación autónoma del negocio sin intervención técnica, garantiza el cumplimiento normativo peruano y provee las herramientas de gestión necesarias para escalar el MVP.

---

## 2. ACTIVIDADES REALIZADAS

### 2.1 Módulo de Historial de Pedidos del Usuario (Módulo 6)

- Desarrollo del componente **Historial de Órdenes** (`OrderHistory`) dentro del perfil del usuario: listado de órdenes con número, fecha, estado (badge visual: `pending`, `confirmed`, `shipped`, `delivered`, `cancelled`) y detalle expandible inline con dirección de envío, email de contacto e items (imagen, nombre, SKU, cantidad).

### 2.2 Módulo de Legal y Compliance (Módulo 8)

- Desarrollo de las **Páginas Legales** (Política de Privacidad – Ley N.° 29733, Términos y Condiciones, Política de Devoluciones, Política de Envíos) con contenido Markdown editable desde CMS, versión y fecha de publicación visibles, y botón "Imprimir / PDF" (`window.print()`).
- Desarrollo del **Libro de Reclamaciones Virtual** conforme al formato INDECOPI: formulario con tipo de reclamo o queja, campos de datos del consumidor, validación de documento (DNI 8 dígitos, RUC 11 dígitos, CE, Pasaporte), descripción del bien/servicio y detalle, generación automática de número de ticket único, pantalla de éxito con ticket visible y aviso del plazo legal de respuesta (15 días hábiles).
- Implementación del endpoint de soporte en la API de integración (`POST /api/v1/support/claims-book`) con notificación por correo electrónico vía Brevo API tanto al consumidor como al equipo administrativo.

### 2.3 Panel de Administración – CMS y Contenido (Módulo 9)

- Desarrollo del **Dashboard Administrativo** con accesos directos a todos los módulos del back-office y resumen visual de tareas.
- Desarrollo del **CMS Landing Home**: editor completo por sección (Hero, Propuesta de Valor, Cómo Funciona, Trust, Sponsors, Testimonios con CRUD, CTA Banner, Picker de Productos Destacados y Picker de FAQs), con preview de imágenes por sección y feedback visual de guardado (loading + toast).
- Desarrollo del **CMS Nosotros**: edición de Hero, Misión/Visión, Timeline, equipo (CRUD) y CTA Banner.
- Desarrollo del **CMS Blog**: CRUD de categorías y posts con soporte de Markdown, imagen destacada con preview, marcación de artículo principal (`is_main`) único, publicación/despublicación con confirmación.
- Desarrollo del **CMS FAQ**: CRUD de categorías y preguntas con reordenamiento manual y activación/desactivación.
- Desarrollo del **CMS Documentos Legales**: editor Markdown con preview en tiempo real, versionado y publicación/desactivación de documentos.

### 2.4 Panel de Administración – Gestión de Inventario (Módulo 10)

- Desarrollo del módulo completo de **Gestión de Inventario** con tabla de productos (nombre, categoría, SKUs, stock total, estado), búsqueda por nombre o SKU y filtro por categoría.
- Implementación de modal de creación/edición de producto: nombre, slug, categoría, descripción, descuento de suscripción, descuento para profesionales y flags de disponibilidad.
- Implementación de gestión de **imágenes** (upload, preview, reordenamiento y eliminación), **variantes** (tipos, SKUs, atributos, precio y stock con bloqueo al activar el producto), **ingredientes** con porcentaje y orden, e **información nutricional** tabular.
- Implementación de flujo de **activación en catálogo** con validación de requisitos mínimos (`activationReady`: nombre, categoría, imagen y variante con atributos) y modal de confirmación.

### 2.5 Panel de Administración – Operaciones (Módulo 11)

- Desarrollo de **Gestión de Pedidos**: listado con filtros por estado, fecha, cliente y número de orden; visualización de detalle completo con desglose IGV; actualización de estado del pedido; procesamiento de devoluciones; y exportación a Excel (`exportOrdersToExcel`).
- Desarrollo de **Gestión de Usuarios y Roles**: listado con filtros, edición de rol con jerarquía de permisos (sin autopromociones a `admin`), y suspensión/reactivación de cuentas (soft delete con `deleted_at`).
- Desarrollo de **Gestión de Cupones y Promociones**: CRUD de cupones con tipo (porcentaje / importe fijo / envío gratis), mínimo de orden, límite de usos, vigencia, activación/desactivación y contador de usos en tiempo real.
- Desarrollo de **Reportes y Métricas**: KPIs (ventas aprobadas, ticket promedio, suscripciones activas, MRR estimado), top productos por ingresos y unidades, evolución de ventas con gráfica de línea, filtros de 7/30/90 días y métricas de IGV (base imponible e IGV recaudado).
- Desarrollo de **Gestión de Reclamos (Admin)**: listado con filtros por estado, búsqueda por ticket o cliente, KPIs rápidos (pendientes, en revisión, resueltos), vista completa del reclamo y modal de respuesta con cambio de estado. Integrado con la API de soporte para notificaciones al consumidor.
- Desarrollo de interfaz de **Validación de Profesionales (Admin)**: UI de listado de solicitudes pendientes y cuentas activas con acciones de aprobación, rechazo y suspensión (en integración con RPCs de back-end).

### 2.6 Infraestructura del Directorio de Especialistas (Módulo 12)

- Diseño del modelo de datos del directorio: tablas `professional_specialties`, `professional_profiles` (con estado de validación `pending / approved / rejected`), `professional_services`, `professional_availability`, `professional_appointments` y `professional_reviews`.
- Implementación de Row-Level Security y RPCs de validación (`approve_professional_account`, `reject_professional_account`, `toggle_professional_account_status`) con restricción de acceso al rol `admin`.
- Desarrollo de la estructura de componentes y páginas del frontend (directorio público, perfil del profesional, búsqueda interactiva, agendamiento) con navegación desactivada hasta completar el proceso de validación y los requisitos de compliance de cobros automáticos MIT.

---

## 3. RESULTADOS OBTENIDOS

- **Historial de pedidos del usuario operativo** (Módulo 6): lista de órdenes con estados, detalle expandible inline e información de envío, accesible desde el perfil del usuario autenticado.
- **Compliance legal implementado** (Módulo 8): cuatro páginas legales según Ley N.° 29733 con contenido editable desde CMS, y Libro de Reclamaciones Virtual conforme a formato INDECOPI con generación automática de ticket, aviso de plazo legal y notificaciones por correo vía Brevo API.
- **Panel de administración CMS completo** (Módulo 9): edición de todo el contenido público de la plataforma (landing, Nosotros, Blog, FAQ y páginas legales) sin intervención técnica, con previews de imagen en tiempo real y feedback visual en cada operación.
- **Gestión de inventario completa** (Módulo 10): CRUD de productos con variantes, imágenes, ingredientes e información nutricional; flujo de activación con validación de requisitos mínimos; y ajuste manual de stock por variante.
- **Operaciones de back-office funcionales** (Módulo 11): administración de pedidos con exportación a Excel, gestión de usuarios con control de roles y suspensión de cuentas, CRUD de cupones con validaciones de negocio, dashboard de reportes con métricas de IGV, y gestión completa del Libro de Reclamaciones desde el panel administrativo.
- **Infraestructura del Directorio de Especialistas definida** (Módulo 12): modelo de datos completo en base de datos con RLS y RPCs de validación, estructura de componentes frontend construida; navegación pública desactivada hasta completar la integración de datos y el compliance de pagos recurrentes MIT.

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
