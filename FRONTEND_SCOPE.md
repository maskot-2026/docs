# Masskot — Alcance Frontend

> **Propósito:** Este documento organiza el alcance del frontend implementado hasta la fecha en User Stories formales con criterios de aceptación, clasificadas por módulo de negocio. Es independiente del `PRODUCT_BACKLOG.md` (que contiene el detalle técnico SQL y seeds); este archivo responde a "¿qué puede hacer el usuario?" para uso en planificación, revisiones de sprint y comunicación con stakeholders.
>
> **Leyenda de estado:**
> - ✅ Implementado y funcional
> - 🔄 Implementado parcialmente / en progreso
> - [ ] Pendiente / no iniciado
> - 🚫 Desactivado intencionalmente (WIP — se activa en sprint futuro)

---

## Índice de Módulos

| # | Módulo | Estado |
|---|--------|--------|
| 1 | [Marketing & Contenido Público](#módulo-1-marketing--contenido-público) | ✅ Implementado |
| 2 | [Tienda y Catálogo](#módulo-2-tienda-y-catálogo) | 🔄 Parcial |
| 3 | [Carrito de Compras](#módulo-3-carrito-de-compras) | 🔄 Parcial |
| 4 | [Checkout y Pagos](#módulo-4-checkout-y-pagos) | 🔄 Parcial |
| 5 | [Cuenta de Usuario](#módulo-5-cuenta-de-usuario) | 🔄 Parcial |
| 6 | [Historial de Pedidos (Usuario)](#módulo-6-historial-de-pedidos-usuario) | 🔄 Parcial |
| 7 | [Suscripciones](#módulo-7-suscripciones) | 🚫 Desactivado |
| 8 | [Legal y Compliance](#módulo-8-legal-y-compliance) | 🔄 Parcial |
| 9 | [Back-office — CMS y Contenido](#módulo-9-back-office--cms-y-contenido) | ✅ Implementado |
| 10 | [Back-office — Inventario](#módulo-10-back-office--inventario) | ✅ Implementado |
| 11 | [Back-office — Operaciones](#módulo-11-back-office--operaciones) | 🔄 Parcial |
| 12 | [Directorio de Especialistas](#módulo-12-directorio-de-especialistas) | 🚫 Futuro |

---

## Módulo 1: Marketing & Contenido Público

> Páginas informativas y de marketing controladas por el CMS. Todo el contenido es editable por el administrador sin intervención de desarrollo.

---

### HU-1.1: Landing Page (Home)

**Como** visitante, **quiero** ver una landing page atractiva con información sobre los productos y beneficios de Masskot **para** decidir si me interesa comprar o suscribirme.

**Criterios de Aceptación:**

- ✅ Sección Hero con imagen, título y CTA configurables desde CMS
- ✅ Sección de Propuesta de Valor con imagen y lista de beneficios
- ✅ Sección "Cómo Funciona" con pasos ilustrados
- ✅ Sección de Trust/Confianza con imagen y texto de respaldo
- ✅ Sección de Sponsors/Aliados con logos
- ✅ Sección de Productos Destacados (slider/cards)
- ✅ Sección de Testimonios de clientes
- ✅ Sección FAQ reducida (preview)
- ✅ Calculadora de ahorro interactiva
- ✅ Sección CTA Banner final con botón
- ✅ Loading skeleton mientras cargan los datos
- ✅ Enlace a catálogo desde productos destacados
- [ ] SEO: meta tags dinámicos por sección

**Frontend:** `src/features/home/pages/LandingPage.tsx`

---

### HU-1.2: Página Nosotros

**Como** visitante, **quiero** conocer la misión, historia y equipo detrás de Masskot **para** generar confianza antes de comprar.

**Criterios de Aceptación:**

- ✅ Sección Hero con imagen y texto configurable
- ✅ Sección Misión y Visión con cards de valores
- ✅ Timeline de hitos de la empresa (orden cronológico)
- ✅ Cards del equipo con foto, nombre y cargo
- ✅ Sección de Certificaciones
- ✅ CTA Banner final configurable
- ✅ Loading skeleton
- [ ] SEO: meta tags dinámicos

**Frontend:** `src/features/about/pages/AboutPage.tsx`

---

### HU-1.3: Preguntas Frecuentes (FAQ)

**Como** visitante, **quiero** consultar respuestas a preguntas comunes sobre productos, envíos y suscripciones **para** resolver dudas sin contactar soporte.

**Criterios de Aceptación:**

- ✅ Listado de categorías de FAQ
- ✅ Accordion de preguntas/respuestas por categoría
- ✅ Filtro o navegación por categoría
- ✅ Loading skeleton
- [ ] Búsqueda por texto libre

**Frontend:** `src/features/faq/pages/FaqPage.tsx`

---

### HU-1.4: Blog

**Como** visitante, **quiero** leer artículos sobre nutrición y cuidado de mascotas **para** obtener información útil y confiar más en la marca.

**Criterios de Aceptación:**

- ✅ Listado de posts con imagen, categoría, título y resumen
- ✅ Artículo principal destacado (marcado como `is_main`)
- ✅ Filtro por categoría
- ✅ Página de detalle del post con contenido enriquecido (Markdown)
- ✅ Loading skeleton en listado y detalle
- [ ] Paginación o carga infinita
- [ ] Compartir en redes sociales
- [ ] Artículos relacionados al final del post

**Frontend:** `src/features/blog/pages/BlogListPage.tsx`, `src/features/blog/pages/BlogPostPage.tsx`

---

## Módulo 2: Tienda y Catálogo

> Experiencia de exploración y selección de productos. Incluye filtros, fichas de producto, ingredientes y reseñas.

---

### HU-2.1: Catálogo de Productos

**Como** usuario, **quiero** explorar el catálogo de productos con filtros y ordenamiento **para** encontrar rápidamente lo que necesito.

**Criterios de Aceptación:**

- ✅ Grid de productos con imagen, nombre, precio y categoría
- ✅ Filtros por categoría
- ✅ Ordenamiento: Más Populares, Menor a Mayor Precio, Mayor a Menor Precio
- ✅ Indicador visual de descuento de suscripción cuando aplica
- ✅ Indicador de producto para profesionales (`is_professional_product`)
- ✅ Loading skeleton
- [ ] Paginación o scroll infinito
- [ ] Filtro por rango de precio
- [ ] Badge de stock bajo / agotado

**Frontend:** `src/features/store/pages/CatalogPage.tsx`

---

### HU-2.2: Ficha de Producto

**Como** usuario, **quiero** ver información detallada de un producto antes de comprarlo **para** tomar una decisión informada.

**Criterios de Aceptación:**

- ✅ Galería de imágenes del producto
- ✅ Selector de variante (ej. peso/presentación)
- ✅ Precio actualizado según variante seleccionada
- ✅ Toggle compra única vs suscripción con % descuento visible
- ✅ Selector de frecuencia de suscripción (semanal / quincenal / mensual)
- ✅ Botón "Agregar al carrito"
- ✅ Tabla nutricional (accordion "Información Nutricional")
- ✅ Lista de ingredientes con porcentaje, origen y descripción
- ✅ Reseñas de usuarios con rating y comentario
- ✅ Rating promedio calculado
- ✅ Breadcrumb de navegación (Inicio > Tienda > [Producto])
- [ ] Galería con zoom (desktop) y swipe (mobile)
- [ ] Sección de productos complementarios (cross-sell)
- [ ] Botón "Agregar al carrito" sticky en mobile

**Frontend:** `src/features/store/pages/ProductDetailPage.tsx`

---

## Módulo 3: Carrito de Compras

> Gestión del carrito antes de proceder al pago. Persistencia por usuario autenticado y por sesión de invitado.

---

### HU-3.1: Gestión del Carrito

**Como** usuario, **quiero** revisar y ajustar los productos en mi carrito antes de pagar **para** confirmar mi pedido correctamente.

**Criterios de Aceptación:**

- ✅ Lista de items con imagen, nombre, variante, cantidad y precio
- ✅ Modificar cantidad de un item (respetando stock)
- ✅ Quitar un item del carrito
- ✅ Toggle compra única / suscripción por item
- ✅ Resumen con subtotal, descuentos, costo de envío e IGV
- ✅ Desglose IGV: Base imponible + IGV 18% mostrado en el resumen
- ✅ Cálculo dinámico de envío por distrito
- ✅ Input de cupón de descuento con validación en tiempo real
- ✅ Persistencia en localStorage para invitados
- ✅ Persistencia en base de datos para usuarios autenticados
- ✅ Botón "Proceder al checkout"
- ✅ Mensaje de error de cupón (mínimo de orden, vigencia) mostrado en tiempo real
- [ ] Sección cross-selling (toppers, snacks, accesorios)
- [ ] Indicador de progreso hasta envío gratis

**Frontend:** `src/features/cart/pages/CartPage.tsx`

---

## Módulo 4: Checkout y Pagos

> Flujo de pago en página única con integración de Mercado Pago Checkout Bricks. Soporte para usuarios autenticados e invitados.

---

### HU-4.1: Flujo de Checkout

**Como** usuario, **quiero** completar mi compra de forma segura en una sola página **para** minimizar fricción y abandonos.

**Criterios de Aceptación:**

- ✅ Checkout en página única con 3 secciones: Datos de facturación, Dirección de envío, Método de pago
- ✅ Autorrellenado de datos de facturación y envío para usuarios autenticados
- ✅ Opción "Agregar nueva dirección" o "Nuevo perfil de facturación" inline (sin salir del checkout)
- ✅ Selector de método de envío con costo y días estimados
- ✅ Integración Mercado Pago Checkout Bricks (tarjeta de crédito/débito)
- ✅ Invitados pueden comprar (sin autorrellenado, sin suscripción recurrente disponible)
- ✅ Desglose de IGV en resumen de orden (Base imponible + IGV 18%)
- 🔄 Checkbox de aceptación de términos y condiciones
- [ ] Texto de consentimiento explícito de tokenización para suscripciones (requerido por Visa/Mastercard para MIT)
- [ ] Email de confirmación automático post-pago

**Frontend:** `src/features/checkout/pages/CheckoutPage.tsx`

---

### HU-4.2: Confirmación de Orden

**Como** usuario, **quiero** ver un resumen de mi compra confirmada después de pagar **para** tener constancia del pedido.

**Criterios de Aceptación:**

- ✅ Número de orden generado y visible con badge de estado
- ✅ Fecha y hora de la orden
- ✅ Resumen de items comprados (imagen, nombre, SKU, cantidad)
- ✅ Desglose de totales (subtotal, descuento, envío, IGV, total)
- ✅ Datos de envío y facturación en snapshot de la orden
- ✅ Enlace para seguir comprando y ver historial de pedidos (si autenticado)
- [ ] Información de seguimiento del envío
- [ ] Comprobante electrónico (boleta/factura vía Nubefact — pendiente activación)

**Frontend:** `src/features/checkout/pages/OrderSuccessPage.tsx`

---

## Módulo 5: Cuenta de Usuario

> Autenticación, gestión de perfil e información de cuenta. Agrupa todo lo relacionado con la identidad y datos personales del usuario registrado.

---

### HU-5.1: Autenticación

**Como** visitante, **quiero** crear una cuenta e iniciar sesión **para** acceder a mis pedidos, guardar mis datos de envío y gestionar suscripciones.

**Criterios de Aceptación:**

- ✅ Registro con email y contraseña
- ✅ `username` obligatorio en registro con email (solo `[a-z0-9_]`, 3–30 caracteres, único)
- ✅ `username` auto-generado (`user_` + hex) en registro con Google OAuth
- ✅ Login con email y contraseña
- ✅ Login social con Google OAuth
- ✅ Flujo de recuperación de contraseña por email (envío de magic link)
- ✅ Verificación de email post-registro
- ✅ Trigger automático: crea `profile` y asigna rol `user` al registrarse
- ✅ Redireccionamiento correcto post-login según rol (user → store, admin → dashboard)
- ✅ Cambiar contraseña vía magic link desde `ResetPasswordPage.tsx` (flujo olvidé contraseña)

**Frontend:** `src/features/security/pages/`

---

### HU-5.2: Perfil Personal

**Como** usuario autenticado, **quiero** ver y editar mis datos personales **para** mantener mi información actualizada.

**Criterios de Aceptación:**

- ✅ Ver username, nombre completo y avatar
- ✅ Editar nombre completo (obligatorio)
- ✅ Editar username (lowercase, sin espacios, validación de unicidad)
- ✅ Subir foto de perfil (avatar con preview)
- ✅ Tipo y número de documento accesibles desde la pestaña de facturación (`BillingManager`)
- [ ] Eliminar cuenta (soft delete con anonimización de datos - Ley 29733)

**Frontend:** `src/features/profile/pages/ProfilePage.tsx`

---

### HU-5.3: Gestión de Direcciones de Envío

**Como** usuario autenticado, **quiero** administrar mis direcciones de envío guardadas **para** agilizar futuros checkouts.

**Criterios de Aceptación:**

- ✅ Listado de direcciones guardadas
- ✅ Agregar nueva dirección con label, destinatario, teléfono, dirección, distrito
- ✅ Editar dirección existente
- ✅ Marcar dirección como predeterminada (sólo una activa a la vez)
- ✅ Eliminar dirección (validando que no afecte suscripciones activas)

**Frontend:** Pestaña `addresses` dentro de `src/features/profile/pages/ProfilePage.tsx`, componente `AddressManager`

---

### HU-5.4: Perfiles de Facturación

**Como** usuario autenticado, **quiero** guardar mis datos de facturación reutilizables (boleta/factura) **para** no ingresarlos en cada compra.

**Criterios de Aceptación:**

- ✅ Listado de perfiles de facturación guardados
- ✅ Crear perfil con label, tipo de documento (DNI / CE / RUC), número, nombre legal y dirección
- ✅ Editar perfil existente
- ✅ Marcar como predeterminado (solo uno activo a la vez)
- ✅ Eliminar perfil

**Frontend:** Pestaña `billing` dentro de `src/features/profile/pages/ProfilePage.tsx`, componente `BillingManager`

---

## Módulo 6: Historial de Pedidos (Usuario)

> Vista del historial de compras desde la cuenta del usuario. No incluye gestión administrativa.

---

### HU-6.1: Listado de Órdenes

**Como** usuario autenticado, **quiero** ver el historial de todas mis órdenes **para** hacer seguimiento de mis compras.

**Criterios de Aceptación:**

- ✅ Listado de órdenes con número, fecha, estado y total
- ✅ Badge de estado del pedido (`pending`, `confirmed`, `shipped`, `delivered`, `cancelled`)
- ✅ Detalle inline expandible: dirección de envío, email de contacto, items (imagen, nombre, SKU, cantidad)
- [ ] Filtro por estado y rango de fechas
- [ ] Paginación

**Frontend:** Pestaña `orders` dentro de `src/features/profile/pages/ProfilePage.tsx`, componente `OrderHistory`

---

### HU-6.2: Detalle de Orden

**Como** usuario autenticado, **quiero** ver el detalle completo de una orden específica **para** conocer exactamente qué compré y el estado del envío.

**Criterios de Aceptación:**

- ✅ Resumen de items (imagen, nombre, SKU, cantidad) — inline expandible en el historial
- ✅ Estado del pedido con badge visual
- [ ] Desglose de totales (subtotal, descuento, envío, IGV, total) en la vista de historial
- [ ] Datos de facturación en la vista de historial
- [ ] Página de detalle independiente con URL propia
- [ ] Descarga del comprobante electrónico (PDF) cuando esté disponible
- [ ] Botón para iniciar una devolución / reclamo

**Frontend:** Detalle inline en el componente `OrderHistory` (pestaña `orders` de `ProfilePage.tsx`)

---

## Módulo 7: Suscripciones

> Gestión de suscripciones activas del usuario. **Desactivado intencionalmente** hasta completar la integración MIT con Mercado Pago y los requisitos de compliance de cobros automáticos.

---

### HU-7.1: Panel de Suscripciones

🚫 **Estado: Desactivado — UI construida pero enlace de navegación oculto hasta completar compliance de cobros MIT.**

**Como** suscriptor, **quiero** gestionar mis suscripciones activas desde mi cuenta **para** tener control sobre los cobros automáticos.

**Criterios de Aceptación:**

- [ ] Listado de suscripciones activas, pausadas y canceladas
- [ ] Card por suscripción: producto, variante, cantidad, frecuencia, próxima fecha de cobro
- [ ] Indicador de estado: `active`, `paused`, `cancelled`, `past_due`
- [ ] Acción: Pausar suscripción (hasta 2 meses)
- [ ] Acción: Reanudar suscripción
- [ ] Acción: Cambiar frecuencia de entrega
- [ ] Acción: Cambiar dirección de envío
- [ ] Acción: Cambiar método de pago
- [ ] Acción: Cancelar suscripción con confirmación
- [ ] **[COMPLIANCE]** Al cancelar, eliminar token de tarjeta en Mercado Pago y en `payment_tokens` (Ley 29733)
- [ ] Método de pago guardado: últimos 4 dígitos y marca de tarjeta visible
- [ ] **[COMPLIANCE]** Eliminación explícita de tarjeta guardada disponible en cualquier momento

**Frontend:** `src/features/profile/pages/SubscriptionsPage.tsx`

---

## Módulo 8: Legal y Compliance

> Páginas de obligado cumplimiento legal según normativa peruana (Ley 29733, INDECOPI, SUNAT).

---

### HU-8.1: Páginas Legales Estáticas

**Como** usuario, **quiero** acceder a los documentos legales de Masskot **para** conocer mis derechos y las condiciones del servicio.

**Criterios de Aceptación:**

- ✅ Política de Privacidad (Ley 29733)
- ✅ Términos y Condiciones
- ✅ Política de Devoluciones
- ✅ Política de Envíos
- ✅ Contenido renderizado desde CMS (editable por administrador sin desarrollo)
- ✅ Versión y fecha de publicación del documento visible
- ✅ Botón "Imprimir / PDF" (`window.print()`)
- [ ] Navegación por secciones (TOC sticky)

**Frontend:** `src/features/legal/pages/LegalDocumentPage.tsx`

---

### HU-8.2: Libro de Reclamaciones Virtual

**Como** usuario, **quiero** presentar una reclamación formal **para** ejercer mis derechos como consumidor según la normativa INDECOPI.

**Criterios de Aceptación:**

- ✅ Formulario según formato INDECOPI (tipo: Reclamo o Queja)
- ✅ Campos: tipo de documento, número, nombre, email, teléfono, dirección
- ✅ Validación de DNI (8 dígitos), RUC (11 dígitos), CE y Pasaporte
- ✅ Descripción del bien/servicio y detalle de la reclamación
- ✅ Generación automática de número de ticket único
- ✅ Pantalla de éxito con número de ticket visible al usuario
- ✅ Aviso de plazo de respuesta legal visible (15 días hábiles)
- [ ] Página de consulta de estado del reclamo por número de ticket
- [ ] Envío de copia por email al consumidor
- [ ] Generación de PDF con formato oficial

**Frontend:** `src/features/legal/pages/ClaimsBookPage.tsx`

---

## Módulo 9: Back-office — CMS y Contenido

> Panel de administración para editar todo el contenido público sin necesidad de intervención técnica. Acceso exclusivo para el rol `admin`.

---

### HU-9.1: Dashboard Administrativo

**Como** administrador, **quiero** un panel de inicio con accesos directos a las secciones clave **para** operar el negocio eficientemente.

**Criterios de Aceptación:**

- ✅ Vista de bienvenida con accesos rápidos a módulos clave
- ✅ Resumen visual de tareas del día
- [ ] KPIs conectados a datos reales (órdenes pendientes, stock bajo, reclamos abiertos)

**Frontend:** `src/features/admin/pages/AdminDashboardPage.tsx`

---

### HU-9.2: CMS Landing Home

**Como** administrador, **quiero** editar todas las secciones de la landing page **para** mantener el contenido actualizado sin depender de desarrollo.

**Criterios de Aceptación:**

- ✅ Editar sección Hero: título, subtítulo, CTA, imagen con preview
- ✅ Editar sección Propuesta de Valor: imagen con preview, lista de beneficios
- ✅ Editar sección "Cómo Funciona": pasos con imagen (preview por paso), título y descripción
- ✅ Editar sección Trust: imagen con preview, texto
- ✅ Editar sección Sponsors: lista de organizaciones con logo (preview por logo, `object-contain`)
- ✅ Editar sección Testimonios: CRUD de testimonios (nombre tutor, nombre mascota, foto mascota con preview, texto, rating 1–5)
- ✅ Editar sección CTA Banner: imagen con preview, título, subtítulo, texto del botón, link
- ✅ Picker de productos destacados (selección desde el catálogo)
- ✅ Picker de FAQs para la sección FAQ reducida de la home
- ✅ Guardado con feedback visual (loading + toast de éxito/error)

**Frontend:** `src/features/admin/content/pages/AdminContentLandingPage.tsx`

---

### HU-9.3: CMS Página Nosotros

**Como** administrador, **quiero** editar la página Nosotros **para** mantener actualizada la historia y el equipo de la empresa.

**Criterios de Aceptación:**

- ✅ Editar Hero: imagen con preview, título, subtítulo
- ✅ Editar sección Misión/Visión con lista de valores
- ✅ Editar Timeline: lista de hitos con año, título y descripción
- ✅ Editar equipo: lista de miembros con foto, nombre, cargo
- ✅ Editar sección Certificaciones
- ✅ Editar CTA Banner: imagen, texto, botón

**Frontend:** `src/features/admin/content/pages/AdminContentAboutPage.tsx`

---

### HU-9.4: CMS Blog

**Como** administrador, **quiero** gestionar el blog completo con categorías y posts **para** publicar contenido relevante para los dueños de mascotas.

**Criterios de Aceptación:**

- ✅ CRUD de categorías de blog (nombre, slug, descripción)
- ✅ CRUD de posts: título, slug, categoría, imagen destacada con preview, contenido Markdown, extracto
- ✅ Marcar/desmarcar un post como artículo principal (`is_main`, único en toda la tabla)
- ✅ Publicar / Despublicar post con confirmación
- ✅ Estado visible del post (publicado / borrador)

**Frontend:** `src/features/admin/content/pages/AdminContentBlogPage.tsx`, `AdminBlogPostModal.tsx`

---

### HU-9.5: CMS FAQ

**Como** administrador, **quiero** gestionar las preguntas frecuentes por categoría **para** mantener la sección FAQ siempre actualizada.

**Criterios de Aceptación:**

- ✅ CRUD de categorías de FAQ (nombre, orden)
- ✅ CRUD de preguntas dentro de cada categoría (pregunta, respuesta, orden)
- ✅ Reordenamiento manual de categorías y preguntas
- ✅ Activar/Desactivar pregunta o categoría

**Frontend:** `src/features/admin/content/pages/AdminContentFaqPage.tsx`

---

### HU-9.6: CMS Documentos Legales

**Como** administrador, **quiero** editar los documentos legales desde el panel **para** actualizar políticas sin intervención técnica.

**Criterios de Aceptación:**

- ✅ Listado de páginas legales (Privacy, Términos, Devoluciones, Envíos)
- ✅ Editor Markdown con preview en tiempo real
- ✅ Campo de versión y fecha de publicación
- ✅ Publicar / Desactivar documento
- [ ] Historial de versiones previas

**Frontend:** `src/features/admin/content/pages/AdminContentLegalPage.tsx`

---

## Módulo 10: Back-office — Inventario

> Gestión completa del catálogo de productos: creación, edición, variantes, stock, imágenes, ingredientes y activación.

---

### HU-10.1: Gestión de Inventario

**Como** administrador, **quiero** gestionar el catálogo completo de productos con todas sus variantes y datos asociados **para** mantener el inventario correcto y actualizado.

**Criterios de Aceptación:**

**Listado y Búsqueda**
- ✅ Tabla de productos con nombre, categoría, SKUs, stock total y estado (`activo` / `inactivo`)
- ✅ Búsqueda por nombre o SKU
- ✅ Filtro por categoría
- ✅ Indicador visual de stock bajo por variante

**Datos Básicos del Producto**
- ✅ Modal de creación/edición: nombre, slug, categoría, descripción, extracto
- ✅ Descuento de suscripción (`sub_discount_pct`) siempre visible y editable
- ✅ Descuento para profesionales (`professional_discount_pct`) siempre visible y editable
- ✅ Flag de producto para profesionales (`is_professional_product`)
- ✅ Flag de disponibilidad para suscripción (`subscription_available`)

**Imágenes**
- ✅ Modal de imágenes: lista de filas con input de URL + preview thumbnail + reordenar (↑↓) + eliminar fila
- ✅ Agregar nueva imagen al final de la lista
- ✅ Preview con fallback a placeholder en caso de URL inválida

**Variantes**
- ✅ Modal de variantes: listado de tipos de variante (ej. "Peso") con sus SKUs y atributos
- ✅ Agregar nuevo tipo de variante con nombre
- ✅ Eliminar cualquier tipo de variante (sin restricción de mínimo)
- ✅ Editar atributos, precio y stock por variante (SKU)
- ✅ Tipos de variante bloqueados (solo lectura) cuando el producto está activo, con banner explicativo
- ✅ Ajuste manual de stock por variante (modal independiente)

**Ingredientes y Nutrición**
- ✅ Modal de ingredientes: agregar/quitar ingredientes con porcentaje y orden
- ✅ Modal de información nutricional: tabla con nutriente, valor, unidad y % diario

**Activación en Catálogo**
- ✅ Activar / Desactivar producto con modal de confirmación
- ✅ `activationReady` evalúa: tiene nombre + categoría + al menos 1 imagen + al menos 1 variante con atributos definidos
- ✅ Modal de activación bloquea si `activationReady = false`, con banner ámbar explicando qué falta
- [ ] Eliminar producto (soft delete)

**Frontend:** `src/features/admin/inventory/pages/AdminInventoryPage.tsx` y modales en `src/features/admin/inventory/`

---

## Módulo 11: Back-office — Operaciones

> Gestión del día a día del negocio: pedidos, usuarios, cupones, reportes, reclamos y validación de profesionales.

---

### HU-11.1: Gestión de Pedidos

**Como** administrador, **quiero** gestionar el ciclo de vida de los pedidos **para** operar la logística y atención al cliente.

**Criterios de Aceptación:**

- ✅ Listado de órdenes con filtros por estado, fecha, cliente y número de orden
- ✅ Búsqueda rápida por número de orden
- ✅ Ver detalle completo: items, dirección, datos de pago, totales y desglose IGV
- ✅ Cambiar estado del pedido (confirmado, en proceso, enviado, entregado)
- ✅ Marcar como enviado / entregado
- ✅ Procesar devolución con cambio de estado
- ✅ Exportar listado de órdenes a Excel (`exportOrdersToExcel`)

**Frontend:** `src/features/admin/orders/pages/AdminOrdersPage.tsx`

---

### HU-11.2: Gestión de Usuarios y Roles

**Como** administrador, **quiero** gestionar las cuentas de usuario y sus permisos **para** mantener el acceso seguro a la plataforma.

**Criterios de Aceptación:**

- ✅ Listado de usuarios con búsqueda y filtros por rol y estado
- ✅ Edición del rol principal (`user` / `professional` / `admin`) con jerarquía (no puede asignarse admin a sí mismo)
- ✅ Suspender / Reactivar usuario (soft delete con `deleted_at`)
- [ ] Invitación o creación manual de usuario

**Frontend:** `src/features/admin/users/pages/AdminUsersPage.tsx`

---

### HU-11.3: Gestión de Cupones y Promociones

**Como** administrador, **quiero** crear y controlar cupones de descuento **para** ejecutar campañas de marketing y retención.

**Criterios de Aceptación:**

- ✅ CRUD de cupones: código, tipo (`percentage` / `fixed_amount` / `free_shipping`), valor, mínimo de orden, límite de usos y vigencia
- ✅ Activar / Desactivar cupón con confirmación
- ✅ Filtros por estado y tipo; búsqueda por código
- ✅ Columna de usos actuales vs. límite visible en la tabla

**Frontend:** `src/features/admin/coupons/pages/AdminCouponsPage.tsx`

---

### HU-11.4: Reportes y Métricas

**Como** administrador, **quiero** ver un dashboard de métricas del negocio **para** tomar decisiones basadas en datos.

**Criterios de Aceptación:**

- ✅ KPIs principales: ventas aprobadas, órdenes aprobadas, ticket promedio, suscripciones activas, MRR estimado
- ✅ Top productos por ingresos y unidades vendidas
- ✅ Evolución de ventas por periodo con gráfica de línea
- ✅ Filtro de rango: últimos 7 / 30 / 90 días y mes actual
- ✅ Métricas de IGV: base imponible total e IGV recaudado en el periodo
- [ ] Exportar resumen de ventas en CSV
- [ ] Exportar reporte IGV para declaración SUNAT (CSV con serie/número de comprobante)

**Frontend:** `src/features/admin/reports/pages/AdminReportsPage.tsx`

---

### HU-11.5: Gestión de Reclamos (Admin)

**Como** administrador, **quiero** atender y gestionar los reclamos del Libro de Reclamaciones **para** cumplir con el plazo legal de respuesta de 30 días (INDECOPI).

**Criterios de Aceptación:**

- ✅ Listado de reclamos con filtros por estado (`pending`, `in_review`, `resolved`, `closed`)
- ✅ Búsqueda por número de ticket o nombre del cliente
- ✅ KPIs rápidos: reclamos pendientes, en revisión y resueltos
- ✅ Ver detalle completo del reclamo (datos del consumidor, bien, detalle del problema)
- ✅ Modal de respuesta con cambio de estado
- [ ] Exportar reporte de reclamos en CSV

**Frontend:** `src/features/admin/claims/pages/AdminClaimsPage.tsx`

---

### HU-11.6: Validación de Profesionales (Admin)

**Como** administrador, **quiero** revisar y aprobar las solicitudes de los profesionales **para** garantizar la calidad del directorio antes de su publicación.

**Criterios de Aceptación:**

- 🔄 Listado de solicitudes pendientes con botones Aprobar / Rechazar / Ver (UI estática — sin integración de datos real)
- 🔄 Listado de cuentas activas con botones Suspender / Ver Perfil (UI estática)
- [ ] Integración con `professional_profiles` vía RPCs (`approve_professional_account`, `reject_professional_account`, `toggle_professional_account_status`)
- [ ] Ver datos de validación reales: RUC, nombre de empresa, documentos adjuntos, especialidad
- [ ] Aprobar perfil (activa descuentos B2B + publica en directorio)
- [ ] Rechazar perfil con motivo de rechazo visible para el solicitante

**Frontend:** `src/features/admin/professionals/pages/AdminProfessionalsPage.tsx`

---

## Módulo 12: Directorio de Especialistas

> Módulo B2B/marketplace de profesionales de mascotas. **Bloqueado para producción** hasta completar el proceso de validación y las capacidades de agendamiento. El frontend está en construcción activa pero los enlaces de navegación están ocultos.

---

### HU-12.1: Landing del Directorio

🚫 **Estado: En desarrollo — navegación desactivada.**

**Como** visitante, **quiero** ver la landing page del directorio de especialistas **para** entender el servicio y cómo encontrar al profesional adecuado.

**Criterios de Aceptación:**

- [ ] Hero con buscador integrado (especialidad + ubicación)
- [ ] Sección de categorías de especialidad dinámicas desde CMS
- [ ] Sección de propuesta de valor ("¿Cómo cuidamos la calidad?")
- [ ] CTA inferior para captar nuevos profesionales ("¿Eres profesional?")
- [ ] Toda la información configurable desde JSONB por el administrador
- [ ] Loading skeleton mientras cargan los datos

**Frontend:** `src/features/professionals/pages/DirectoryLandingPage.tsx`

---

### HU-12.2: Registro y Perfil del Profesional

🚫 **Estado: En desarrollo.**

**Como** profesional de mascotas, **quiero** registrarme en la plataforma y crear mi perfil público **para** que dueños de mascotas me encuentren y acceder a los descuentos B2B.

**Criterios de Aceptación:**

- [ ] Formulario de solicitud: datos legales (RUC, empresa) + datos del perfil (título, especialidad principal)
- [ ] Estado de validación visible: Pendiente / Aprobado / Rechazado
- [ ] Al ser aprobado: perfil publicado automáticamente + descuentos B2B activados en la tienda
- [ ] Panel de gestión del perfil: nombre público, título, resumen de experiencia
- [ ] Catálogo de servicios con precios "desde"
- [ ] Galería de fotos (clínica, equipos, espacio) — 4 a 6 imágenes
- [ ] Dirección con coordenadas (lat/lng) para mapa
- [ ] Sistema de testimonios con rating (1–5 estrellas) — solo desde citas completadas

**Frontend:** `src/features/professionals/pages/ProfessionalRegistrationPage.tsx`, `ProfessionalProfilePage.tsx`

---

### HU-12.3: Búsqueda Interactiva y Mapa

🚫 **Estado: En desarrollo.**

**Como** dueño de mascota, **quiero** buscar profesionales cercanos con filtros **para** encontrar rápidamente al más adecuado para mi caso.

**Criterios de Aceptación:**

- [ ] Filtros: especialidad, tipo de consulta, ordenar por (rating / precio / nombre), texto libre
- [ ] Chips de filtros activos removibles
- [ ] Vista split (desktop): listado a la izquierda + mapa interactivo a la derecha
- [ ] Vista toggle (mobile): listado o mapa
- [ ] Tarjeta de profesional: foto, nombre, título, rating con estrellas, dirección, tipos de consulta, precio base
- [ ] Mapa Google Maps con pins por profesional, InfoWindow al hacer clic

**Frontend:** `src/features/professionals/pages/SpecialistsPage.tsx`

---

### HU-12.4: Agendamiento de Citas

🚫 **Estado: Pendiente — requiere HU-12.3 completa.**

**Como** usuario, **quiero** reservar una cita con un profesional directamente desde su perfil **para** agendar la atención de mi mascota de forma rápida.

**Criterios de Aceptación:**

- [ ] Widget "Booking" en la ficha del profesional
- [ ] Selector de motivo de cita (servicio)
- [ ] Grilla de horarios con franjas de disponibilidad
- [ ] Confirmación con resumen de la cita
- [ ] Testimonios validados (solo tras cita completada)

**Frontend:** `src/features/professionals/pages/ProfessionalDetailPage.tsx`, `BookingWidget.tsx`

---

### HU-12.5: Descuentos B2B para Profesionales

🚫 **Estado: Pendiente — se activa automáticamente al aprobar el perfil del profesional.**

**Como** profesional habilitado, **quiero** acceder automáticamente a precios mayoristas en la tienda **para** comprar a precio especial sin gestiones adicionales.

**Criterios de Aceptación:**

- [ ] Si el usuario tiene `professional_profiles.status = 'approved'`, la tienda renderiza vista con precios mayoristas
- [ ] `professional_discount_pct` por producto visible en catálogo y ficha de producto
- [ ] Precio con descuento aplicado en carrito y checkout

**Frontend:** `src/features/store/hooks/useProfessionalDiscount.ts`

---

## Apéndice: Matriz de Estado Global

| HU | Módulo | Descripción | Estado |
|----|--------|-------------|--------|
| HU-1.1 | Marketing | Landing Page Home | ✅ |
| HU-1.2 | Marketing | Página Nosotros | ✅ |
| HU-1.3 | Marketing | FAQ | ✅ |
| HU-1.4 | Marketing | Blog | ✅ |
| HU-2.1 | Tienda | Catálogo de Productos | ✅ |
| HU-2.2 | Tienda | Ficha de Producto | ✅ |
| HU-3.1 | Carrito | Gestión del Carrito | 🔄 |
| HU-4.1 | Checkout | Flujo de Checkout | 🔄 |
| HU-4.2 | Checkout | Confirmación de Orden | ✅ |
| HU-5.1 | Cuenta | Autenticación | ✅ |
| HU-5.2 | Cuenta | Perfil Personal | ✅ |
| HU-5.3 | Cuenta | Direcciones de Envío | ✅ |
| HU-5.4 | Cuenta | Perfiles de Facturación | ✅ |
| HU-6.1 | Pedidos | Historial de Órdenes | ✅ |
| HU-6.2 | Pedidos | Detalle de Orden | 🔄 |
| HU-7.1 | Suscripciones | Panel de Suscripciones | 🚫 |
| HU-8.1 | Legal | Páginas Legales | ✅ |
| HU-8.2 | Legal | Libro de Reclamaciones | 🔄 |
| HU-9.1 | Admin CMS | Dashboard | ✅ |
| HU-9.2 | Admin CMS | CMS Landing Home | ✅ |
| HU-9.3 | Admin CMS | CMS Nosotros | ✅ |
| HU-9.4 | Admin CMS | CMS Blog | ✅ |
| HU-9.5 | Admin CMS | CMS FAQ | ✅ |
| HU-9.6 | Admin CMS | CMS Documentos Legales | ✅ |
| HU-10.1 | Admin Inventario | Gestión de Inventario | ✅ |
| HU-11.1 | Admin Ops | Gestión de Pedidos | ✅ |
| HU-11.2 | Admin Ops | Usuarios y Roles | ✅ |
| HU-11.3 | Admin Ops | Cupones y Promociones | ✅ |
| HU-11.4 | Admin Ops | Reportes y Métricas | ✅ |
| HU-11.5 | Admin Ops | Reclamos (Admin) | ✅ |
| HU-11.6 | Admin Ops | Validación Profesionales | 🔄 |
| HU-12.1 | Directorio | Landing Directorio | 🚫 |
| HU-12.2 | Directorio | Registro Profesional | 🚫 |
| HU-12.3 | Directorio | Búsqueda + Mapa | 🚫 |
| HU-12.4 | Directorio | Agendamiento | 🚫 |
| HU-12.5 | Directorio | Descuentos B2B | 🚫 |
