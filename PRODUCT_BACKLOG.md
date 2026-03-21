# 🐾 MasKot - Product Backlog (MVP Simplificado - Fase 1)

> Plataforma de nutrición para mascotas - Modelo AltuDog  
> **Stack:** React 19 + Vite + TypeScript + Tailwind CSS + Supabase

---

## 📋 Índice de Módulos

1. [Identidad y Landings](#módulo-1-identidad-y-landings)
2. [Tienda E-commerce](#módulo-2-tienda-e-commerce)
3. [Checkout y Suscripción](#módulo-3-checkout-y-suscripción)
4. [Legal y Compliance](#módulo-4-legal-y-compliance-perú)
5. [Administración Back-office](#módulo-5-administración-back-office)
6. [Módulos Complementarios](#módulo-6-complementarios)
7. [Directorio Profesional](#módulo-7-directorio-profesional)

---

## Módulo 1: Identidad y Landings

### HU-1.1: Home Page con Hero Dinámico

**User Story:** Como visitante, quiero ver una página de inicio atractiva con información clara, para entender el valor de la nutrición personalizada.

**Criterios de Aceptación:**

- [ ] Hero banner dinámico con título, subtítulo y CTA "Descubre tu plan ideal"
- [ ] Sección comparador de costos: comida tradicional vs MasKot
- [ ] Slider interactivo para simular ahorro según peso/edad de mascota
- [ ] Sección "Cómo funciona" en 3 pasos con iconos
- [ ] Carrusel de testimonios con foto de mascota, nombre del dueño y rating
- [ ] Mostrar testimonios destacados (configurables desde admin)
- [ ] Banner CTA final con llamado a acción
- [ ] Loading skeleton mientras cargan datos dinámicos
- [ ] Mobile-first responsive

**NOTA:** Ultima seccion de Organizaciones Aliadas o Patrocinadores, Startup Perú 12G, Incubagraria, Santander X.

**Frontend:** `src/features/home/pages/LandingPage.tsx` + `homePageService.ts`

**Supabase (`01_identity_landings`):**

```sql
-- Tabla de configuracion del home
CREATE TABLE home_page_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    
    -- 1er Bloque: Atracción e Introducción
    hero_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    value_proposition_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 2do Bloque: Conversión y Producto (Dinámico por IDs)
    featured_products_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 3er Bloque: Explicación y Confianza
    how_it_works_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    trust_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    sponsors_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 4to Bloque: Herramientas y Prueba Social (Dinámico por IDs)
    calculator_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    testimonials_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 5to Bloque: Cierre y Dudas (Dinámico por IDs)
    faq_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    cta_banner_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_blog_posts_single_main ON blog_posts (is_main) WHERE is_main = TRUE;

-- Datos iniciales (Seed) para la Home Page
INSERT INTO home_page_config (
    id, 
    hero_section, 
    value_proposition_section, 
    featured_products_section, 
    how_it_works_section, 
    trust_section, 
    sponsors_section, 
    calculator_section, 
    testimonials_section, 
    faq_section, 
    cta_banner_section
) VALUES (
    1,
    
    -- [SECCIÓN 1] HERO: Lo primero que ve el usuario (Captura 1 Superior)
    $$
    {
        "title": "Alimentación premium para tu perro, en un plan mensual a su medida.",
        "subtitle": "Elige su receta ideal y recíbela en casa con continuidad.",
        "cta_text": "Ver Tienda",
        "cta_link": "/store",
        "hero_images": [
            "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=900&q=80",
            "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=900&q=80",
            "https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=900&q=80",
            "https://images.unsplash.com/photo-1601758124510-52d02ddb7cbd?auto=format&fit=crop&w=900&q=80"
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 2] VALUE PROPOSITION: Enganche rápido (Captura 1 Inferior)
    $$
    {
        "title": "¿Qué ganas con +Kot desde el primer mes?",
        "subtitle": "Alimentarlo bien no debería ser complicado. +Kot te ayuda a tomar una decisión segura y práctica.",
        "image_url": "https://images.unsplash.com/photo-1601758124510-52d02ddb7cbd?auto=format&fit=crop&w=1200&q=80",
        "benefits": [
            "Recibes la cantidad justa para su consumo mensual, sin comprar de más o quedarte corto.",
            "Mantienes continuidad y control: eliges y luego ajustas según su rutina real.",
            "Ganas tranquilidad: claridad en lo que le das y un proceso simple de inicio a entrega."
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 3] FEATURED PRODUCTS: Dinámico (IDs) - (Captura 2)
    -- El frontend iterará sobre product_ids, hará fetch a la tabla products y renderizará la comparativa de compra.
    $$
    {
        "title": "¿Por qué elegir este producto para tu perro?",
        "subtitle": "Un producto premium pensado para el día a día. Desliza para ver más opciones.",
        "product_ids": [1, 2, 3]
    }
    $$::jsonb,

    -- [SECCIÓN 4] HOW IT WORKS: Reduce fricción (Captura 3 Superior)
    $$
    {
        "title": "¿Cómo funciona la suscripción paso a paso?",
        "steps": [
            { "step_number": "01", "description": "Calculas el plan ideal con datos simples.", "image_url": "https://images.unsplash.com/photo-1558788353-f76d92427f16?auto=format&fit=crop&w=800&q=80" },
            { "step_number": "02", "description": "Eliges la receta y confirmas tu plan mensual.", "image_url": "https://images.unsplash.com/photo-1583512603805-3cc6b41f3edb?auto=format&fit=crop&w=800&q=80" },
            { "step_number": "03", "description": "Pagas y coordinamos la entrega.", "image_url": "https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=800&q=80" },
            { "step_number": "04", "description": "Recibes en casa y ajustas tu plan cuando sea necesario.", "image_url": "https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80" }
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 5] TRUST: Garantías antes del pago (Captura 3 Inferior)
    $$
    {
        "title": "¿Por qué puedes confiar en +Kot?",
        "image_url": "https://images.unsplash.com/photo-1535930749574-1399327ce78f?auto=format&fit=crop&w=1200&q=80",
        "reasons": [
            { "number": "01", "title": "Transparencia en lo que compras", "description": "Queremos que tengas claridad desde el inicio: qué incluye tu plan, qué estás dando y por qué se recomienda." },
            { "number": "02", "title": "Continuidad sin fricción", "description": "La suscripción existe para hacerlo fácil. Recibes con continuidad y mantienes el control del proceso." },
            { "number": "03", "title": "Un plan que evoluciona con tu perro", "description": "Los perros cambian, y su alimentación también. Si cambia su rutina, tu plan puede ajustarse." }
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 6] SPONSORS: Autoridad de marca
    $$
    {
        "title": "Respaldados por",
        "organizations": [
            {
                "name": "Startup Perú 12G",
                "logo_url": "https://ruta-startup.com/wp-content/uploads/2023/06/763d8-6e192791-3825-4aef-9574-4f9407f058ba-1-1.png"
            },
            {
                "name": "Santander X",
                "logo_url": "https://explorerbyx.org/assets/icons/sx_explorer-logo-vector.svg"
            },
            {
                "name": "Incubagraria",
                "logo_url": "https://incubagraria.lamolina.edu.pe/wp-content/uploads/2025/08/LOGO-INCUBAGRARIA.png"
            }
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 7] CALCULATOR: Interacción
    $$
    {
        "title": "¿Cuánto cuesta alimentar bien a tu mascota?",
        "description": "Compara el costo de la comida tradicional vs +Kot. Prevenimos enfermedades a largo plazo con nutrición preventiva."
    }
    $$::jsonb,

    -- [SECCIÓN 8] TESTIMONIALS: Dinámico (Ahora JSON Array) - Prueba social final
    $$
    {
        "title": "Mascotas felices,",
        "highlight_title": "familias tranquilas",
        "description": "No lo decimos nosotros, lo dicen cientos de perros y gatos que ya cambiaron su vida con +Kot.",
        "testimonials": [
            {
                "pet_name": "Max",
                "owner_name": "Carlos R.",
                "content": "Desde que Max come MasKot, su digestión mejoró increíblemente y tiene mucha más energía.",
                "rating": 5,
                "pet_photo_url": "https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=200&h=200"
            },
            {
                "pet_name": "Luna",
                "owner_name": "Ana M.",
                "content": "El pelaje de Luna nunca ha estado tan brillante. Le encanta el sabor de la receta de pollo.",
                "rating": 5,
                "pet_photo_url": "https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&q=80&w=200&h=200"
            },
            {
                "pet_name": "Rocky",
                "owner_name": "Jorge L.",
                "content": "Batallábamos con alergias en la piel hasta que probamos MasKot. Es un cambio de vida total.",
                "rating": 5,
                "pet_photo_url": "https://images.unsplash.com/photo-1537151608804-ea2f1cb0464f?auto=format&fit=crop&q=80&w=200&h=200"
            }
        ]
    }
    $$::jsonb,

    -- [SECCIÓN 9] FAQS: Dinámico (IDs) - Ataja objeciones (Captura 4 Superior)
    $$
    {
        "title": "Preguntas frecuentes",
        "description": "Resolvemos tus principales dudas sobre la suscripción y envíos.",
        "faq_ids": [10, 20, 40, 60] 
    }
    $$::jsonb,

    -- [SECCIÓN 10] CTA FINAL: Última oportunidad de conversión (Captura 4 Inferior)
    $$
    {
        "title": "Descubre el plan perfecto para tu perro",
        "subtitle": "Explora nuestros productos premium y elige el plan mensual que mejor se adapte a tu mascota.",
        "cta_text": "Ver Tienda",
        "cta_link": "/store",
        "image_url": "https://images.unsplash.com/photo-1601758174114-e711c0cbaa69?auto=format&fit=crop&w=1200&q=80"
    }
    $$::jsonb
);

-- RPC: Calculadora Nutricional Definitiva con Fórmula RER Veterinaria
CREATE OR REPLACE FUNCTION calculate_cost_savings(
    p_pet_weight_kg NUMERIC,
    p_pet_age_months INTEGER,
    p_activity_level TEXT DEFAULT 'normal',
    p_is_neutered BOOLEAN DEFAULT FALSE,
    p_body_condition TEXT DEFAULT 'ideal',
    p_pet_type TEXT DEFAULT 'dog'
) RETURNS JSONB AS $$
    -- Calcula: RER, MER, gramos diarios recomendados, y compara costos (mensual, ahorro anual)
    -- Basado en fórmula NRC 2006 y precios del mercado
$$ LANGUAGE plpgsql SECURITY INVOKER;
```

---

### HU-1.2: Página "Nosotros"

**User Story:** Como visitante, quiero conocer la filosofía y equipo de MasKot, para generar confianza antes de comprar.

**Criterios de Aceptación:**

- [ ] Hero banner con título y subtítulo de la página
- [ ] Sección Misión/Visión con animaciones al scroll
- [ ] Timeline interactivo de historia de la empresa
- [ ] Grid de miembros del equipo con foto, nombre, rol y LinkedIn
- [ ] Galería de certificaciones y avales veterinarios
- [ ] Banner CTA final
- [ ] Loading skeleton
- [ ] Mobile-first responsive

**Frontend:** `src/features/about/pages/AboutPage.tsx`

**Supabase (`01_identity_landings`):**

```sql


-- Configuración de Página "Nosotros"
CREATE TABLE about_page_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    hero_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    mission_vision_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    timeline_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    team_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    certifications_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    cta_banner_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);



INSERT INTO about_page_config (id, hero_section, mission_vision_section, timeline_section, team_section, certifications_section, cta_banner_section) VALUES (
    1,
    '{
      "title": "Nuestra Historia",
      "subtitle": "Nacimos por amor a ellos. Todo comenzó cuando no podíamos encontrar comida real en el mercado tradicional, así que decidimos cocinarla nosotros mismos.",
      "image_url": "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=1200"
    }'::jsonb,
    '{
      "mission": "Revolucionar la salud de las mascotas a través de nutrición preventiva, natural y transparente.",
      "vision": "Convertirnos en la alternativa número 1 a las croquetas tradicionales en toda la región, alargando la esperanza y calidad de vida de perros y gatos."
    }'::jsonb,
    '{
      "title": "Nuestro Crecimiento",
      "events": [
        {"year": "2022", "title": "La primera receta", "description": "Comenzamos en una cocina casera formulando la primera receta para Max, nuestro perro fundador."},
        {"year": "2023", "title": "Aprobación Veterinaria", "description": "Lanzamos comercialmente nuestras primeras 3 recetas tras rigurosas pruebas de formulación AAFCO."},
        {"year": "2024", "title": "Expansión Nacional", "description": "Abrimos nuestra cocina industrial grado humano y comenzamos a enviar a todo el país."}
      ]
    }'::jsonb,
    '{
        "title": "Conoce al Equipo",
        "subtitle": "Personas apasionadas detrás de la felicidad de tu mascota.",
        "members": [
            {
                "full_name": "Dra. María Fernández",
                "role": "Fundadora & Veterinaria Principal",
                "photo_url": "https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&q=80&w=200&h=200",
                "bio": "Especialista en nutrición de pequeños animales con más de 15 años de experiencia clínica.",
                "linkedin_url": "https://linkedin.com"
            },
            {
                "full_name": "Carlos Mendoza",
                "role": "Jefe de Producción Culinaria",
                "photo_url": "https://images.unsplash.com/photo-1577219491135-ce391730fb2c?auto=format&fit=crop&q=80&w=200&h=200",
                "bio": "Chef profesional que decidió aplicar su talento a la nutrición saludable para mascotas tras adoptar a su perro.",
                "linkedin_url": "https://linkedin.com"
            },
            {
                "full_name": "Lucía Rivera",
                "role": "Directora de Atención MasKot",
                "photo_url": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=200&h=200",
                "bio": "Entusiasta del servicio al cliente y amante de los gatos. Lidera nuestro equipo de felicidad perruna y gatuna.",
                "linkedin_url": "https://linkedin.com"
            }
        ]
    }'::jsonb,
    '{
        "title": "Nuestras Certificaciones",
        "subtitle": "Calidad y seguridad comprobada.",
        "items": [
            {
                "name": "Aprobado por Veterinarios",
                "logo_url": "https://cdn-icons-png.flaticon.com/512/2839/2839213.png",
                "description": "Todas nuestras recetas exceden los perfiles de nutrientes de la AAFCO."
            },
            {
                "name": "Ingredientes Grado Humano",
                "logo_url": "https://cdn-icons-png.flaticon.com/512/3063/3063822.png",
                "description": "Utilizamos pollo, res y cerdo 100% apto para consumo humano."
            }
        ]
    }'::jsonb,
    '{
        "title": "¿Convencido de la comida real?",
        "subtitle": "Tu mascota merece saber qué se siente comer ingredientes frescos cada día.",
        "cta_text": "Ver Planes",
        "cta_link": "/store"
    }'::jsonb
);
```

---

### HU-1.3: FAQ / Preguntas Frecuentes

**User Story:** Como visitante, quiero encontrar respuestas rápidas a mis principales dudas sobre la comida MasKot, envíos y suscripciones.

**Criterios de Aceptación:**

- [ ] Sección de FAQs destacadas en el Landing Page.
- [ ] Página independiente (`/faqs`) con todas las categorías de preguntas.
- [ ] Listado de preguntas frecuentes agrupadas por categoría (p. ej. "Sobre la Comida", "Envíos", "Suscripción").
- [ ] Diseño acordeón interactivo para mostrar/ocultar respuestas.
- [ ] Búsqueda en tiempo real por palabra clave.

**Frontend:** `src/features/faq/pages/FaqPage.tsx`, `LandingPage.tsx`

**Supabase (`01_identity_landings`):**

```sql
-- Categorías de FAQs
CREATE TABLE faq_categories (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0)
);

-- Preguntas Frecuentes
CREATE TABLE faqs (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    category_id BIGINT REFERENCES faq_categories(id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Datos iniciales (Seed) para FAQs
INSERT INTO faq_categories (id, name, slug, display_order) VALUES
(1, 'Sobre la Comida', 'sobre-la-comida', 10),
(2, 'Suscripción y Pagos', 'suscripcion-pagos', 20),
(3, 'Envíos y Entregas', 'envios-entregas', 30);

INSERT INTO faqs (category_id, question, answer, display_order) VALUES
(1, '¿Los ingredientes son aptos para consumo humano?', 'Sí. Todos nuestros ingredientes provienen de proveedores certificados para consumo humano (grado humano). No usamos descartes, harinas ni conservantes.', 10),
(1, '¿Tengo que cocinar la comida cuando me llegue?', '¡No! Las raciones de MasKot ya vienen cocinadas al vapor a bajas temperaturas para mantener los nutrientes y listas para servir.', 20),
(1, '¿Debería hacer una transición gradual?', 'Sí, recomendamos una transición de 7 a 10 días mezclando MasKot gradualmente con el alimento actual para evitar malestares estomacales.', 30),
(2, '¿Puedo cancelar o pausar mi suscripción?', 'Absolutamente. Tienes control total desde tu panel de usuario para pausar, adelantar pedidos o cancelar en cualquier momento sin penalizaciones.', 40),
(2, '¿Cuándo me cobran?', 'El cobro se realiza automáticamente a tu tarjeta de crédito o débito 24 horas antes de procesar tu siguiente envío.', 50),
(3, '¿Cómo llega la comida?', 'Enviamos nuestra comida en cajas térmicas especiales que la mantienen congelada o refrigerada hasta llegar a la puerta de tu casa.', 60),
(3, '¿Hacen envíos a todo el país?', 'Actualmente llegamos a toda Lima Metropolitana y provincias seleccionadas. Ingresa tu código postal en el checkout para confirmar cobertura.', 70);
```

---

### HU-1.4: Blog Educativo con CMS

**User Story:** Como visitante, quiero acceder a contenido educativo sobre nutrición de mascotas.

**Criterios de Aceptación:**

- [ ] Listado de artículos con paginación (12/página)
- [ ] Cards con imagen destacada, título, description y tiempo de lectura
- [ ] Filtros por categoría
- [ ] Búsqueda por título/contenido
- [ ] Vista de artículo individual con slug SEO-friendly
- [ ] Tabla de contenidos (TOC) sticky en desktop
- [ ] Autor del artículo con avatar y nombre
- [ ] Artículos relacionados al final
- [ ] SEO: meta_title, meta_description
- [ ] Estados: borrador, publicado, archivado
- [ ] Share buttons (WhatsApp, Facebook, Copy link)

**Frontend:** `src/features/blog/pages/BlogListPage.tsx`, `BlogPostPage.tsx`

**Supabase (`01_identity_landings`):**

```sql
-- Categorías de blog
CREATE TABLE blog_categories (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0)
);

-- Posts de blog
CREATE TABLE blog_posts (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    content TEXT NOT NULL,
    featured_image_url TEXT,
    category_id BIGINT REFERENCES blog_categories(id) ON DELETE SET NULL,
    author_id BIGINT REFERENCES profiles(id) ON DELETE SET NULL,
    read_time_minutes INTEGER NOT NULL DEFAULT 5 CHECK (read_time_minutes > 0),
    is_main BOOLEAN NOT NULL DEFAULT FALSE,
    meta_title TEXT,
    meta_description TEXT,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Datos iniciales (Seed) para el Blog
INSERT INTO blog_categories (id, name, slug, display_order) VALUES
(1, 'Nutrición Natural', 'nutricion-natural', 10),
(2, 'Salud Preventiva', 'salud-preventiva', 20),
(3, 'Comportamiento', 'comportamiento', 30);

INSERT INTO blog_posts (slug, title, description, content, featured_image_url, category_id, read_time_minutes, is_main, published_at) VALUES
('5-mitos-sobre-croquetas', '5 Mitos sobre las croquetas que la industria no quiere que sepas', 'Descubre la verdad detrás de las bolitas marrones y por qué la comida fresca es superior.', $$Las croquetas comerciales han sido la norma durante décadas, pero hay puntos que vale la pena revisar.

## Lo que debes saber
- La lista de ingredientes cuenta la historia completa.
- Menos ultraprocesados significa mejor digestion.
- La hidratacion importa tanto como la proteina.

**Conclusión:** elegir comida real cambia la energia, el pelaje y la salud intestinal.$$ , 'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&q=80&w=800&h=400', 1, 5, TRUE, NOW()),
('guia-transicion-comida-natural', 'Guía paso a paso para la transición a comida natural', 'El cambio de dieta debe ser gradual. Sigue estos 4 pasos para cuidar la digestión de tu mascota.', $$Cambiar la dieta de tu perro o gato requiere paciencia.

## Pasos recomendados
1. **Dia 1-2:** 75% comida actual + 25% MasKot.
2. **Dia 3-4:** 50% + 50%.
3. **Dia 5-6:** 25% + 75%.
4. **Dia 7:** 100% MasKot.

Si notas sensibilidad, mantén un paso extra antes de avanzar.$$ , 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=800&h=400', 1, 7, FALSE, NOW()),
('beneficios-omega-3', 'Los increíbles beneficios del Omega 3 en perros mayores', 'Previene el deterioro cognitivo y mejora la movilidad articular con este ácido graso esencial.', $$El Omega 3 es clave para mantener activos a los perros senior.

## Beneficios principales
- Apoya la movilidad y reduce inflamacion articular.
- Favorece la salud cognitiva.
- Mejora el brillo del pelaje.

**Tip:** busca fuentes de calidad como aceite de salmon salvaje.$$ , 'https://images.unsplash.com/photo-1537151608804-ea2f1cb0464f?auto=format&fit=crop&q=80&w=800&h=400', 2, 4, FALSE, NOW());
```

---

## Módulo 2: Tienda (E-commerce)

### HU-2.1: Catálogo de Productos

**User Story:** Como usuario, quiero ver productos disponibles para comprar.

**Criterios de Aceptación:**

- [ ] Listado de productos con cards: imagen, nombre, precio, rating
- [ ] Filtros por: categoría, rango de precio, tipo de alimento
- [ ] Ordenar por: precio (asc/desc), popularidad
- [ ] Vista grid/lista toggle
- [] Lazy loading de imágenes
- [ ] Skeleton loaders

**Frontend:** `src/features/store/pages/CatalogPage.tsx`

**Supabase (`02_store_ecommerce`):**

```sql

-- Categorías de productos
CREATE TABLE product_categories (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    parent_id BIGINT REFERENCES product_categories(id) ON DELETE SET NULL,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0)
);

CREATE TABLE products (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    short_description TEXT,
    sub_discount_pct INTEGER DEFAULT 0 CHECK (sub_discount_pct BETWEEN 0 AND 100),
    images TEXT[] NOT NULL DEFAULT '{}',
    category_id BIGINT REFERENCES product_categories(id) ON DELETE SET NULL,
    variants JSONB NOT NULL DEFAULT '{}'::jsonb, -- Opciones/variantes (ej. tamaño, peso, precio, stock)
    subscription_available BOOLEAN NOT NULL DEFAULT TRUE,
    published_at TIMESTAMPTZ, -- auto set when product is activated the first time
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    is_professional_product BOOLEAN NOT NULL DEFAULT FALSE,
    professional_discount_pct INTEGER DEFAULT 0 CHECK (professional_discount_pct BETWEEN 0 AND 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reviews de productos
CREATE TABLE product_reviews (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    profile_id BIGINT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice único: 1 review por usuario por producto
CREATE UNIQUE INDEX idx_unique_reviews_user_per_product ON product_reviews(product_id, profile_id);

-- Datos iniciales (Seed) para Tienda
INSERT INTO product_categories (id, name, slug, display_order) VALUES
(1, 'Alimento Seco', 'alimento-seco', 1),
(2, 'Alimento Húmedo', 'alimento-humedo', 2),
(3, 'Snacks Naturales', 'snacks-naturales', 3),
(4, 'Suplementos', 'suplementos', 4);

-- Semilla de Productos (Stock disponible, listos para pruebas B2C)
INSERT INTO products (
    name, slug, description, short_description, price, compare_at_price, 
    images, category_id, variants, subscription_available, 
    stock_quantity, published_at, is_active
) VALUES
('Receta Res y Verduras (Seco)', 'receta-res-verduras-seco', $$Alimento horneado lentamente, alto en proteínas.

**Beneficios principales**
- Proteina animal para energia diaria.
- Verduras reales para fibra y digestion suave.
- Coccion lenta para conservar nutrientes.

**Ideal para** perros activos y rutinas exigentes.$$ , 'Proteína de calidad para perritos activos.', 25.00, 30.00, 
    '{"https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&q=80&w=600&h=600"}', 1, 
    '[{"sku": "DRY-001-2A", "attributes": {"Peso": "2kg", "Tipo": "Adulto"}, "price": 25.00, "stock": 50}, {"sku": "DRY-001-2C", "attributes": {"Peso": "2kg", "Tipo": "Cachorro"}, "price": 28.00, "stock": 50}, {"sku": "DRY-001-5A", "attributes": {"Peso": "5kg", "Tipo": "Adulto"}, "price": 55.00, "stock": 50}]'::jsonb, true, 100, NOW(), true),

('Pate de Pollo Orgánico', 'pate-pollo-organico', $$Libre de granos, ideal para estomagos sensibles.

**Beneficios principales**
- Pollo real como primer ingrediente.
- Textura suave para perros y gatos delicados.
- Coccion al vapor que conserva el sabor.$$ , 'Pate premium sin conservantes.', 5.50, NULL, 
    '{"https://images.unsplash.com/photo-1583336829158-9419b456108b?auto=format&fit=crop&q=80&w=600&h=600"}', 2, 
    '[{"sku": "WET-001-400", "attributes": {"Peso": "400g"}, "price": 5.50, "stock": 200}]'::jsonb, true, 200, NOW(), true),

('Tiras de Lomo Deshidratado', 'tiras-lomo-deshidratado', $$100% res deshidratada a baja temperatura.

**Beneficios principales**
- Alto en proteina para energia inmediata.
- Textura firme que ayuda a la masticacion.
- Sin aditivos ni conservantes.$$ , 'El premio perfecto para entrenamiento.', 12.00, 15.00, 
    '{"https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&q=80&w=600&h=600"}', 3, 
    '[{"sku": "SNC-001-200", "attributes": {"Peso": "200g"}, "price": 12.00, "stock": 50}]'::jsonb, false, 50, NOW(), true),

('Aceite de Salmón Salvaje', 'aceite-salmon-salvaje', $$Rico en Omega 3 y 6 para piel y pelaje brillantes.

**Beneficios principales**
- Ayuda a reducir inflamacion.
- Aporta brillo visible al pelaje.
- Apoya la salud cognitiva en perros adultos.$$ , 'Shot de brillo para el pelaje.', 22.00, NULL, 
    '{"https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&q=80&w=600&h=600"}', 4, 
    '[{"sku": "SUP-001-250", "attributes": {"Volumen": "250ml"}, "price": 22.00, "stock": 30}]'::jsonb, true, 30, NOW(), true);

-- Semilla de Reviews de prueba
INSERT INTO product_reviews (product_id, profile_id, rating, comment) VALUES
(1, 1, 5, 'A mi perrito le encantó, su pelaje está mucho mejor.'),
(1, 2, 4, 'Buen producto pero el empaque llegó un poco doblado.'),
(2, 1, 5, 'Excelente para mezclar con sus croquetas habituales.');
```

---

### HU-2.2: Ficha de Producto

**User Story:** Como usuario, quiero ver información detallada de un producto incluyendo ingredientes.

**Criterios de Aceptación:**

- [ ] Galería de imágenes con zoom y swipe en mobile
- [ ] Selector de peso/presentación
- [ ] Toggle: Compra única vs Suscripción con % descuento visible
- [ ] Selector de frecuencia de suscripción (semanal, quincenal, mensual)
- [ ] Tabla nutricional completa
- [ ] Listado de ingredientes ordenados por porcentaje
- [ ] Reviews de usuarios con rating y comentario
- [ ] Rating promedio calculado
- [ ] Sección de productos complementarios (cross-sell)
- [ ] Botón "Agregar al carrito" sticky en mobile
- [ ] Breadcrumb de navegación

**Frontend:** `src/features/store/pages/ProductDetailPage.tsx`

**Supabase (`02_store_ecommerce`):**

```sql
-- Ingredientes
CREATE TABLE ingredients (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    origin_country TEXT,
    supplier TEXT
);

-- Ingredientes por producto
CREATE TABLE product_ingredients (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    ingredient_id BIGINT NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    percentage NUMERIC(5, 2) CHECK (percentage BETWEEN 0 AND 100),
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0)
);

-- Información nutricional
CREATE TABLE product_nutrition_facts (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    nutrient TEXT NOT NULL,
    value NUMERIC(10, 2) NOT NULL,
    unit TEXT NOT NULL,
    daily_pct NUMERIC(5, 2) CHECK (daily_pct >= 0)
);

-- Semilla de Ingredientes
INSERT INTO ingredients (id, name, description, origin_country, supplier) VALUES
(1, 'Carne de Res Magra', 'Fuente principal de proteína de alto valor biológico', 'Perú', 'Matadero Local Certificado'),
(2, 'Zanahoria', 'Rica en betacaroteno y fibra para digestión', 'Perú', 'Agricultores del Valle'),
(3, 'Pollo de Corral', 'Proteína de fácil digestión', 'Perú', 'Granjas Orgánicas'),
(4, 'Semillas de Chía', 'Superfood alto en Omega 3 vegetal', 'Perú', 'EcoAndes'),
(5, 'Aceite de Salmón Salvaje', 'EPA y DHA puros para cerebro y articulaciones', 'Alaska', 'AlaskaSeafood'),
(6, 'Hígado de Res', 'Multivitamínico natural, alto en hierro', 'Perú', 'Matadero Local Certificado');

-- Semilla de Ingredientes por Producto (Asignando a DRY-001 y WET-001)
-- DRY-001 (Receta Res y Verduras)
INSERT INTO product_ingredients (product_id, ingredient_id, percentage, display_order) VALUES
(1, 1, 60.00, 1),
(1, 6, 10.00, 2),
(1, 2, 25.00, 3),
(1, 4, 5.00, 4);

-- WET-001 (Pate de Pollo Orgánico)
INSERT INTO product_ingredients (product_id, ingredient_id, percentage, display_order) VALUES
(2, 3, 80.00, 1),
(2, 2, 15.00, 2),
(2, 4, 5.00, 3);

-- Semilla de Información Nutricional (DRY-001)
INSERT INTO product_nutrition_facts (product_id, nutrient, value, unit, daily_pct) VALUES
(1, 'Proteína Cruda (min)', 35.0, '%', NULL),
(1, 'Grasa Cruda (min)', 15.0, '%', NULL),
(1, 'Fibra Cruda (max)', 3.0, '%', NULL),
(1, 'Humedad (max)', 10.0, '%', NULL),
(1, 'Calorías (Kcal/kg)', 3800, 'Kcal', NULL);

-- Semilla de Información Nutricional (WET-001)
INSERT INTO product_nutrition_facts (product_id, nutrient, value, unit, daily_pct) VALUES
(2, 'Proteína Cruda (min)', 12.0, '%', NULL),
(2, 'Grasa Cruda (min)', 8.0, '%', NULL),
(2, 'Humedad (max)', 75.0, '%', NULL),
(2, 'Calorías (Kcal/lata)', 250, 'Kcal', NULL);
```

---

### HU-2.3: Carrito de Compras

**User Story:** Como usuario, quiero gestionar mi carrito antes de pagar.

**Criterios de Aceptación:**

- [ ] Agregar productos al carrito (validar stock disponible)
- [ ] Quitar productos del carrito
- [ ] Modificar cantidades con validación de stock
- [ ] Toggle compra única/suscripción por item
- [ ] Mostrar subtotal, descuentos aplicados, costo de envío, total
- [ ] Cálculo de envío por distrito
- [ ] Sección cross-selling: toppers, snacks, accesorios
- [ ] Input de cupón de descuento con validación
- [ ] Validar mínimo de orden y vigencia del cupón
- [ ] Persistir carrito para usuarios logueados
- [ ] Persistir en localStorage para guests
- [ ] Botón "Proceder al checkout"

**Frontend:** `src/features/store/pages/CartPage.tsx`

**Supabase (`02_store_ecommerce`):**

```sql
CREATE TYPE coupon_type AS ENUM ('percentage', 'fixed_amount', 'free_shipping');

-- Zonas de envío
CREATE TABLE shipping_zones (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    district TEXT NOT NULL,
    province TEXT NOT NULL DEFAULT 'Lima',
    department TEXT NOT NULL DEFAULT 'Lima',
    shipping_cost NUMERIC(10, 2) NOT NULL CHECK (shipping_cost >= 0),
    delivery_days INTEGER NOT NULL DEFAULT 3 CHECK (delivery_days > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Cupones de descuento
CREATE TABLE coupons (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    type coupon_type NOT NULL,
    value NUMERIC(10, 2) NOT NULL CHECK (value >= 0),
    min_order NUMERIC(10, 2) CHECK (min_order >= 0),
    max_uses INTEGER CHECK (max_uses > 0),
    used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT FALSE
);

-- Carritos
CREATE TABLE carts (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT REFERENCES profiles(id) ON DELETE CASCADE,
    session_id TEXT UNIQUE,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    coupon_id BIGINT REFERENCES coupons(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice único: Solo 1 carrito activo por usuario autenticado
CREATE UNIQUE INDEX idx_unique_carts_per_user ON carts(profile_id) WHERE profile_id IS NOT NULL;

-- Índice único: Solo 1 carrito activo por sesión guest
CREATE UNIQUE INDEX idx_unique_carts_per_session ON carts(session_id) WHERE session_id IS NOT NULL AND profile_id IS NULL;

-- Semilla de Zonas de Envío (Ejemplo Lima)
INSERT INTO shipping_zones (district, province, department, shipping_cost, delivery_days) VALUES
('Miraflores', 'Lima', 'Lima', 10.00, 1),
('San Isidro', 'Lima', 'Lima', 10.00, 1),
('Surco', 'Lima', 'Lima', 12.00, 2),
('La Molina', 'Lima', 'Lima', 15.00, 2),
('San Borja', 'Lima', 'Lima', 12.00, 1),
('Barranco', 'Lima', 'Lima', 10.00, 1),
('Lince', 'Lima', 'Lima', 10.00, 1),
('Jesus Maria', 'Lima', 'Lima', 10.00, 1),
('Pueblo Libre', 'Lima', 'Lima', 10.00, 1),
('San Miguel', 'Lima', 'Lima', 12.00, 2);

-- Semilla de Cupones de Prueba
INSERT INTO coupons (code, type, value, min_order, max_uses) VALUES
('BIENVENIDA10', 'percentage', 10.00, 50.00, 100),
('ENVIOFREE', 'free_shipping', 0, 100.00, 50),
('DSCTO20', 'fixed_amount', 20.00, 120.00, 20);

-- RPC: Calcular totales del carrito con envío y validación de cupones integrada
CREATE OR REPLACE FUNCTION calculate_cart_totals(
    p_cart_id BIGINT,
    p_district TEXT,
    p_coupon_code TEXT DEFAULT NULL
) RETURNS JSONB AS $$
    -- Retorna: { subtotal, shipping_cost, discount, total, delivery_days, has_free_shipping, coupon_error, applied_coupon }
$$ LANGUAGE plpgsql SECURITY INVOKER;
```

---

## Módulo 3: Checkout y Suscripción

### HU-3.1: Flujo de Checkout

**User Story:** Como usuario, quiero completar mi compra de forma segura.

**Criterios de Aceptación:**

- [x] Checkout en 1 sola página con 3 secciones principales:
- [x] Sección 1: Datos de Facturación/Boleta (Autorrellenado para usuarios autenticados)
- [x] Sección 2: Dirección de Envío (Autorrellenado para usuarios autenticados)
- [x] Opción "Agregar nueva dirección" o "Nuevo perfil de facturación" en el mismo flujo
- [x] Paso 3: Método de envío con costo y días estimados
- [x] Sección 3: Método de pago (Mercado Pago Checkout Bricks — integrado en la misma página)
- [x] Usuarios Guest (sin autenticar): Pueden comprar normalmente, pero **no** tienen autorrellenado y **no** pueden suscribirse a productos recurrentes.
- [ ] Aceptación de términos y condiciones (checkbox obligatorio)
- [ ] **[COMPLIANCE]** Texto de consentimiento explícito de tokenización para suscripciones: _"Al realizar esta compra, autorizas a MasKot a guardar tu tarjeta de forma segura en Mercado Pago para procesar los cobros automáticos de tu suscripción. Puedes cancelar en cualquier momento desde tu cuenta."_ — Requerido por Visa/Mastercard para cobros MIT (Merchant Initiated Transactions). Sin este texto, cualquier contracargo lo gana automáticamente el usuario.
- [ ] Generar número de orden único al confirmar
- [ ] Página de confirmación con resumen del pedido
- [ ] Email de confirmación automático

**Frontend:** `src/features/checkout/pages/CheckoutPage.tsx`

**Supabase (`03_checkout_subscriptions`):**

```sql
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'approved', 'rejected', 'cancelled', 'in_process', 'in_mediation', 'charged_back', 'refunded');
CREATE TYPE card_brand AS ENUM ('visa', 'mastercard', 'amex', 'diners', 'other');

-- Direcciones de envío
CREATE TABLE shipping_addresses (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    district TEXT NOT NULL,
    province TEXT NOT NULL DEFAULT 'Lima',
    department TEXT NOT NULL DEFAULT 'Lima',
    postal_code TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (profile_id, label)
);

-- Índice único: Solo 1 dirección default por usuario
CREATE UNIQUE INDEX idx_unique_addresses_default_per_user ON shipping_addresses(profile_id) WHERE is_default = TRUE;

-- Perfiles de Facturación (Boleta/Factura reutilizables)
CREATE TABLE billing_profiles (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    doc_type document_type NOT NULL,
    doc_number TEXT NOT NULL,
    legal_name TEXT NOT NULL,
    legal_address TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (profile_id, label)
);

-- Índice único: Solo 1 perfil de facturación default por usuario
CREATE UNIQUE INDEX idx_unique_billing_default_per_user ON billing_profiles(profile_id) WHERE is_default = TRUE;

-- Tokens de pago (Mercado Pago vault)
CREATE TABLE payment_tokens (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token_id TEXT NOT NULL,        -- MP card ID (ej: 1773089741151)
    customer_id TEXT NOT NULL,     -- ID del customer en la pasarela de pago — requerido para generar tokens MIT en cobros futuros
    last_four TEXT NOT NULL,
    card_brand card_brand NOT NULL,
    expires_at TIMESTAMPTZ,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (profile_id, token_id)
);

-- Índice único: Solo 1 token de pago default por usuario
CREATE UNIQUE INDEX idx_unique_tokens_default_per_user ON payment_tokens(profile_id) WHERE is_default = TRUE;

-- Órdenes
CREATE TABLE orders (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT REFERENCES profiles(id) ON DELETE SET NULL,
    cart_session_id TEXT,  -- Guest session ID para identificar carrito post-pago
    status order_status NOT NULL DEFAULT 'pending',
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    shipping_cost NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    total NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
    shipping_address JSONB NOT NULL DEFAULT '{}',
    billing_profile JSONB NOT NULL DEFAULT '{}', -- Snapshot inmutable de los datos de facturación al momento de la compra
    payment_status payment_status NOT NULL DEFAULT 'pending',
    transaction_id TEXT UNIQUE, -- ID final de la transacción bancaria
    checkout_id TEXT, -- Intención de pago o session ID de la pasarela
    contact_email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Items de orden
CREATE TABLE order_items (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL, -- Copia snapshot inmutable
    variant_sku TEXT NOT NULL, -- Copia snapshot inmutable
    variant_attributes JSONB NOT NULL DEFAULT '{}'::jsonb, -- Atributos de la variante exacta que el usuario eligió al comprar
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0),
    is_subscription BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_frequency_days INTEGER CHECK (subscription_frequency_days > 0)
);

```sql
CREATE OR REPLACE FUNCTION create_order(
    p_cart_id BIGINT,
    p_shipping_address JSONB,
    p_billing_profile JSONB,
    p_contact_email TEXT,
    p_checkout_id TEXT DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL  -- Guest session ID
) RETURNS JSONB AS $$
    -- Transacción:
    -- 1. Validar stock de cada item (fail-fast antes de tocar nada)
    -- 2. Incrementar cupón (solo si stock OK)
    -- 3. Crear orden + items (con session_id para guests)
    -- 4. Reservar stock
    -- Retorna: { order_id, total }
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Limpiar carrito de una orden post-pago
CREATE OR REPLACE FUNCTION clear_order_cart(
    p_order_id BIGINT
) RETURNS JSONB AS $$
    -- Busca la orden → obtiene profile_id o session_id
    -- Remueve items seleccionados/comprados del carrito
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Restaurar stock y revertir cupón de una orden
CREATE OR REPLACE FUNCTION restore_order_stock(
    p_order_id BIGINT
) RETURNS JSONB AS $$
    -- Restaura stock de cada variante en order_items
    -- Revierte used_count del cupón si aplica
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Auto-cancelar órdenes pendientes expiradas (30 min sin pagar)
CREATE OR REPLACE FUNCTION cancel_expired_pending_orders()
RETURNS JSONB AS $$
    -- PERFORM restore_order_stock(order_id) para cada orden expirada
    -- UPDATE orders SET status='cancelled', payment_status='cancelled'
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Eliminación de métodos de pago y perfiles asociados a la orden
CREATE OR REPLACE FUNCTION delete_payment_token(p_token_id BIGINT) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION delete_shipping_address(p_address_id BIGINT) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE OR REPLACE FUNCTION delete_billing_profile(p_profile_id BIGINT) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

-- CRON: Ejecutar cada 5 minutos (requiere pg_cron habilitado en Supabase)
SELECT cron.schedule('cancel-expired-orders', '*/5 * * * *', $$SELECT cancel_expired_pending_orders()$$);
```

---

### HU-3.2: Panel de Gestión de Suscripción

**User Story:** Como suscriptor, quiero gestionar mi suscripción desde mi cuenta.

**Criterios de Aceptación:**

- [ ] Listado de suscripciones activas, pausadas o canceladas del usuario
- [ ] Card por suscripción: producto, cantidad, frecuencia, próximo cobro
- [ ] Indicador de estado (`active`, `paused`, `cancelled`, `past_due`/pago fallido)
- [ ] Acción: Pausar suscripción activa (máx 2 meses)
- [ ] Acción: Reanudar suscripción (desde `paused` con Catch-Up, `cancelled` bajo demanda o `past_due` con Reset de Ciclo para prevenir overstocking)
- [ ] Acción: Adelantar o cambiar fecha del próximo envío
- [ ] Acción: Cambiar frecuencia de entrega
- [ ] Acción: Cambiar método de pago y dirección de envío
- [ ] Acción: Cancelar suscripción
- [ ] **[COMPLIANCE]** Eliminación de tarjeta: al cancelar cuenta o solicitar borrado de datos de pago, llamar a `mp_sdk.card().delete(customer_id, card_id)` en MP y eliminar el registro en `payment_tokens`. Obligatorio por protección de datos (Ley 29733).
- [ ] **[COMPLIANCE]** Notificación pre-cobro: enviar email automático 2-3 días antes de cada renovación con monto, tarjeta (últimos 4 dígitos) y link para pausar/cancelar. Reduce contracargos drásticamente. generadas automáticamente (ej. `created`, `paused`, `resumed`, `cancelled`, `reactivated`, `renewal`, `payment_failed`, `frequency_changed`)

**Frontend:** `src/features/account/pages/SubscriptionsPage.tsx`

**Supabase (`03_checkout_subscriptions`):**

```sql
CREATE TYPE subscription_status AS ENUM ('active', 'paused', 'cancelled', 'past_due');
CREATE TYPE subscription_action AS ENUM ('created', 'paused', 'resumed', 'cancelled', 'reactivated', 'renewal', 'payment_failed', 'frequency_changed', 'product_changed', 'address_changed', 'payment_changed');

-- Suscripciones
CREATE TABLE subscriptions (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT REFERENCES profiles(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES products(id) ON SET NULL,
    product_name TEXT NOT NULL,
    variant_sku TEXT NOT NULL,
    variant_attributes JSONB NOT NULL DEFAULT '{}'::jsonb,
    variant_price NUMERIC(10, 2) NOT NULL CHECK (variant_price > 0),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    frequency_days INTEGER NOT NULL DEFAULT 30 CHECK (frequency_days > 0),
    status subscription_status NOT NULL DEFAULT 'active',
    next_billing_date TIMESTAMPTZ NOT NULL,
    shipping_address_id BIGINT REFERENCES shipping_addresses(id) ON DELETE SET NULL,
    billing_profile_id BIGINT REFERENCES billing_profiles(id) ON DELETE SET NULL,
    payment_token_id BIGINT REFERENCES payment_tokens(id) ON DELETE SET NULL,
    pause_until TIMESTAMPTZ,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Historial de suscripción
CREATE TABLE subscription_history (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    subscription_id BIGINT NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    action subscription_action NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1. Creación de la suscripción (usada desde webhook y admin manual)
CREATE OR REPLACE FUNCTION create_subscriptions_from_order(
    p_order_id BIGINT
) RETURNS JSONB AS $$
    -- Resuelve perfiles y tokens desde la orden e inserta la tabla subscriptions
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Cancelar suscripciones relacionadas a un refund
CREATE OR REPLACE FUNCTION cancel_subscriptions_for_order(
    p_order_id BIGINT,
    p_cancel_reason TEXT DEFAULT 'Order refunded/charged back'
) RETURNS JSONB AS $$
    -- Cancela y loguea histórico
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Controlador de Estado (Status: active, paused, cancelled, past_due)
CREATE OR REPLACE FUNCTION manage_subscription_status(
    p_subscription_id BIGINT,
    p_new_status subscription_status,
    p_pause_days INTEGER DEFAULT NULL,
    p_cancel_reason TEXT DEFAULT NULL,
    p_charge_immediately BOOLEAN DEFAULT TRUE
) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Billing recurrente (CRON-based)
CREATE OR REPLACE FUNCTION advance_subscription_billing(
    p_subscription_id BIGINT,
    p_invoice_id TEXT
) RETURNS JSONB AS $$
    -- Actualiza el next_billing_date tras cobro existoso
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_due_subscriptions()
RETURNS JSONB AS $$
    -- Recupera las suscripciones listas para cobro recurrente
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- 5. Trigger para Historial Automático
CREATE OR REPLACE FUNCTION log_subscription_history() RETURNS TRIGGER AS $$ $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_subscription_history
AFTER INSERT OR UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION log_subscription_history();

-- Datos Iniciales de Prueba (Suscripciones)
-- Instrucción: Reemplazar {profile_id} con el ID generado en la tabla 'profiles'.
INSERT INTO payment_tokens (profile_id, token_id, last_four, card_brand, is_default)
VALUES ({profile_id}, 'tok_mock_123456789', '4242', 'visa', TRUE);

INSERT INTO billing_profiles (profile_id, label, doc_type, doc_number, legal_name, legal_address, is_default)
VALUES ({profile_id}, 'Boleta de Prueba', 'DNI', '12345678', 'Usuario de Pruebas', 'Av. Los Mockers 123, Lima', TRUE);

INSERT INTO shipping_addresses (profile_id, label, recipient_name, phone, address_line1, district, province, department, is_default)
VALUES ({profile_id}, 'Mi Casa de Pruebas', 'Usuario de Pruebas', '999999999', 'Av. Los Mockers 123', 'La Victoria', 'Lima', 'Lima', TRUE);

-- Nota: Insertar la suscripción asegurándose de reemplazar los de abajo por los IDs correctos generados en las inserciones anteriores.
INSERT INTO subscriptions (profile_id, product_id, product_name, variant_sku, variant_attributes, quantity, frequency_days, status, next_billing_date, shipping_address_id, billing_profile_id, payment_token_id) 
VALUES ({profile_id}, 1, 'Receta Base (Mock)', 'SKU-MOCK-01', '{"peso": "500g"}'::jsonb, 1, 15, 'active', CURRENT_DATE + 15, {shipping_address_id}, {billing_profile_id}, {payment_token_id});
```

> **📌 Nota Técnica — Tokenización y Compliance de Cobros MIT**
>
> **Arquitectura de seguridad:** El sistema usa tokenización vía `_save_card_to_mp_customer`. Lo que se guarda en Supabase (`payment_tokens.token_id`) es un identificador opaco (ej. `card_1234abcd`) que **solo funciona en la cuenta específica de Mercado Pago de MasKot**. El número real de tarjeta, fecha y CVV nunca tocan nuestros servidores — son responsabilidad exclusiva de MP (PCI-DSS Nivel 1). Riesgo de fuga de datos de tarjetas: **cero**.
>
> **Responsabilidad legal de cobros automáticos:** Técnicamente es posible cobrar al usuario en cualquier momento con el token guardado. Hacerlo sin consentimiento previo constituye **fraude**. Un contracargo exitoso resulta en: devolución al usuario, descuento + multa al comercio, y bloqueo de cuenta MP si el porcentaje supera ~1%. Los tres requisitos para cobros automáticos legítimos son: (1) consentimiento explícito en el checkout, (2) notificación pre-cobro 2-3 días antes, (3) mecanismo de cancelación accesible siempre.
>
> **Arquitectura de órdenes huérfanas:** Las órdenes en `payment_status='pending'` que no reciben webhook de MP en 15 minutos son canceladas automáticamente por `cancel_expired_pending_orders()` vía pg_cron (cada 5 min), restaurando stock y cupón. El backend de integración no hace rollback manual — delega esa responsabilidad al cron.

---

## Módulo 4: Legal y Compliance (Perú)

### HU-4.1: Páginas Legales Estáticas

**User Story:** Como usuario, quiero acceder a información legal clara.

**Criterios de Aceptación:**

- [ ] Página de Política de Privacidad (Ley 29733 - Perú)
- [ ] Página de Términos y Condiciones
- [ ] Página de Política de Devoluciones
- [ ] Página de Política de Envíos
- [ ] Contenido dinámico desde CMS
- [ ] Mostrar versión y fecha de publicación del documento
- [ ] Navegación por secciones (TOC sticky)
- [ ] Botón de versión imprimible / exportar PDF
- [ ] SEO: meta tags dinámicos por página

**Frontend:** `src/features/legal/pages/LegalDocumentPage.tsx`

**Supabase (`04_legal_compliance`):**

```sql
-- Páginas de contenido legal (manejadas como CMS)
CREATE TABLE content_pages (
    id      BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    slug    TEXT NOT NULL UNIQUE,
    title   TEXT NOT NULL,
    content TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT '1.0',

    -- Control de vigencia
    is_active    BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,

    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO content_pages (slug, title, content, is_active, published_at) VALUES 
(
    'privacy-policy', 
    'Política de Privacidad', 
    $$
El presente documento describe los tratamientos de datos personales que llevamos a cabo en MasKot. Su privacidad es de suma importancia para nosotros, y estamos comprometidos con la transparencia.

## 1. Finalidad del Tratamiento
Recopilamos su información con las siguientes finalidades secundarias e inherentes a la prestación de nuestros servicios:

- Procesar sus **órdenes de compra** y suscripciones recurrentes de manera segura.
- Enviar actualizaciones sobre el estado de su envío a través de correo electrónico o teléfono celular.
- Atender dudas, reclamos y sugerencias a través del Libro de Reclamaciones Virtual.

### 1.1 Base de Datos
Sus datos son almacenados en un servidor seguro en la nube. Puede consultar más detalles ingresando [aquí](/nosotros).

## 2. Transferencia a Terceros
MasKot S.A.C. compartirá los datos mínimos necesarios, como nombre y dirección, estrictamente con nuestros proveedores logísticos para cumplir con las rutas de despacho (última milla).
    $$, 
    true, 
    NOW()
), 
(
    'terms-conditions', 
    'Términos y Condiciones', 
    $$
Bienvenido a MasKot. Los siguientes términos y condiciones regulan el uso de este sitio web y establecen la relación comercial vigente entre usted (el usuario) y nosotros.

## 1. Condiciones Generales
El uso continuo de esta plataforma digital constituye su aceptación expresa de estos términos. **Si no está de acuerdo, por favor absténgase de usar el portal.**

> "Nuestra misión es cuidar la salud de tu mascota de forma transparente y predecible."

## 2. Políticas de Facturación
1. Todos los precios mostrados incluyen IGV.
2. En el caso de las suscripciones, se realizará un cargo automático según la frecuencia que usted seleccione.
3. Los comprobantes de pago (Boleta/Factura) se emiten automáticamente tras confirmarse el abono.
    $$, 
    true, 
    NOW()
), 
(
    'returns-policy', 
    'Política de Devoluciones', 
    $$
En MasKot garantizamos la calidad de nuestros productos. Si recibe un artículo defectuoso o incorrecto, nuestro equipo lo resolverá a la brevedad posible.

## 1. Requisitos para la Devolución
- El producto debe de mantenerse **sellado y en su empaque original**.
- Debe realizar el reclamo en un plazo máximo de *7 días calendario posteriores a la recepción* del pedido.
- Adjuntar el comprobante de pago electrónico.

## 2. Proceso de Cambio
Para iniciar el proceso, comuníquese con nuestro equipo de soporte enviando fotografías legibles del inconveniente. Luego procesaremos una orden de recojo a domicilio sin costo adicional, siempre que el error sea logístico.
    $$, 
    true, 
    NOW()
), 
(
    'shipping-policy', 
    'Política de Envíos', 
    $$
Nuestra prioridad es que el alimento de tu mascota llegue a tiempo. Para lograrlo, mantenemos una política de despachos centralizada.

## 1. Áreas de Cobertura
Actualmente despachamos a lo largo de **Lima Metropolitana y Callao** de acuerdo a zonas pre-establecidas. El costo de despacho se calcula de forma dinámica en la ventana de pago o *Checkout*.

### 1.1 Consideraciones
- Los tiempos estimados de entrega son de **24 a 48 horas hábiles** dependiendo de la demanda.
- Las entregas se realizan entre las 9:00 a.m. y las 6:00 p.m.

## 2. Fallos en Entrega
Si el despachador no lograra ubicar a una persona autorizada en el domicilio luego de un tiempo de espera de 15 minutos, el producto retornará a nuestras instalaciones y se programará una segunda visita (la cual tendrá costo adicional).
    $$, 
    true, 
    NOW()
);
 
```

---

### HU-4.2: Libro de Reclamaciones Virtual

**User Story:** Como usuario, quiero presentar una reclamación formal según normativa peruana.

**Criterios de Aceptación:**

- [ ] Formulario según formato INDECOPI
- [ ] Selector de tipo: Reclamo o Queja
- [ ] Datos del consumidor: tipo documento, número, nombre, email, teléfono
- [ ] Validación de DNI (8 dígitos)
- [ ] Descripción del producto/servicio
- [ ] Detalle de la reclamación
- [ ] Pedido del consumidor
- [ ] Generación automática de número de reclamo
- [ ] Estado del reclamo (pendiente, en revisión, resuelto, cerrado)
- [ ] Generación de PDF con formato oficial
- [ ] Envío de copia por email al consumidor
- [ ] Plazo de respuesta visible (30 días calendario)
- [ ] Página de consulta de estado del reclamo

**Frontend:** `src/features/legal/pages/ClaimsBookPage.tsx`

**Supabase (`04_legal_compliance`):**

```sql
CREATE TYPE claim_type AS ENUM ('claim', 'complaint');
CREATE TYPE claim_status AS ENUM ('pending', 'in_review', 'resolved', 'closed');
CREATE TYPE document_type AS ENUM ('dni', 'ce', 'passport', 'ruc');

-- Libro de reclamaciones
CREATE TABLE claims (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ticket_number TEXT NOT NULL UNIQUE,
    
    -- ESTADO
    type claim_type NOT NULL,
    status claim_status NOT NULL DEFAULT 'pending',
    
    -- QUIÉN (Datos del Consumidor)
    doc_type document_type NOT NULL, 
    doc_number TEXT NOT NULL,
    legal_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT NOT NULL,
    
    -- EL PROBLEMA (Detalle del Bien y Reclamo)
    good_type good_type NOT NULL,
    claimed_amount NUMERIC(10, 2), 
    good_description TEXT NOT NULL,
    
    details TEXT NOT NULL,
    petition TEXT NOT NULL,
    
    -- LA SOLUCIÓN
    response TEXT, 
    responded_at TIMESTAMPTZ,
    
    -- ARCHIVOS
    pdf_url TEXT,

    -- METADATA
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Módulo 5: Administración (Back-office)

### HU-5.1: Reportes y métricas

**User Story:** Como administrador, quiero revisar reportes de ventas y suscripciones para tomar decisiones rápidas.

**Criterios de Aceptación:**

- [x] Cards con ventas aprobadas, órdenes aprobadas, ticket promedio, suscripciones activas y MRR estimado.
- [x] Listado de top productos por ingresos y unidades vendidas.
- [x] Evolución de ventas por periodo (día/semana/mes).
- [x] Filtro de rango: últimos 7/30/90 días y mes actual.
- [ ] Exportar resumen en CSV.

**Frontend:** `src/features/admin/reports/pages/AdminReportsPage.tsx`

**Supabase (`05_admin_backoffice`):**

```sql
-- RPC: Resumen de reportes (ventas y suscripciones)
CREATE OR REPLACE FUNCTION get_reports_overview(
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB AS $$
    -- Retorna: { total_sales, approved_orders, avg_order_value, active_subscriptions, mrr, top_products[] }
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Evolución de ventas por periodo
CREATE OR REPLACE FUNCTION get_sales_evolution(
    p_date_from TIMESTAMPTZ,
    p_date_to TIMESTAMPTZ,
    p_granularity TEXT DEFAULT 'day'
) RETURNS JSONB AS $$
    -- Retorna: [{ date, total_sales, order_count }]
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### HU-5.2: Gestión de Pedidos

**User Story:** Como administrador, quiero gestionar el ciclo de vida de pedidos.

**Criterios de Aceptación:**

- [x] Listado de órdenes con filtros: estado, fecha, cliente, número de orden.
- [x] Ver detalle completo: items, dirección, pago.
- [x] Cambiar estado del pedido.
- [x] Marcar como enviado/entregado.
- [x] Procesar devolución con cambio de estado.
- [x] Búsqueda rápida por número de orden.

**Frontend:** `src/features/admin/orders/pages/AdminOrdersPage.tsx`

**Supabase (`05_admin_backoffice`):**

```sql
-- Sin RPCs adicionales para esta HU.
-- La actualizacion de estado se realiza con un update directo a la tabla orders.
```

---

### HU-5.3: Gestión de Inventario

**User Story:** Como administrador, quiero controlar el stock de productos.

**Criterios de Aceptación:**

- [x] Listado de productos con stock actual y alertas de stock bajo.
- [x] Busqueda por nombre o SKU.
- [x] Filtro por categoria.
- [x] Indicador visual de stock bajo.
- [x] Crear y editar producto base (datos principales, B2B, suscripciones).
- [x] Gestion de imagenes, ingredientes, nutricion y variantes.
- [x] Agregar y quitar variantes.
- [x] Activar/Desactivar producto en catalogo con validaciones.
- [x] Ajuste manual de stock por variante.
- [ ] Eliminar producto.

**Frontend:** `src/features/admin/inventory/pages/AdminInventoryPage.tsx`

**Supabase (`05_admin_backoffice`):**

```sql
-- El stock se gestiona en products.variants[*].stock.
-- La gestion de catalogo se realiza con CRUD directo en products.
-- No se usan tablas adicionales ni RPC para esta HU.
```

---

### HU-5.4: Gestión del Directorio Profesional (B2B)

**User Story:** Como administrador, quiero validar y gestionar las cuentas de los profesionales antes de que aparezcan en el directorio público y accedan a descuentos.

**Criterios de Aceptación:**

- [ ] Listado de perfiles profesionales pendientes de aprobación.
- [ ] Ver datos de validación: RUC, colegiatura, sustentos.
- [ ] Aprobar/Rechazar perfil para publicarlo en el directorio y otorgar beneficios B2B.
- [ ] Suspender/Reactivar perfil en caso de mala praxis o inactividad.

**Frontend:** `src/features/admin/professionals/pages/AdminProfessionalsPage.tsx`

**Supabase (`05_admin_backoffice`):**

```sql
-- La estructura de professional_profiles ahora se define íntegramente en el Módulo 7 (HU-7.1)
-- Aquí solo se listan para visibilidad los RPCs administrativos para cambiar los estados, 
-- los cuales están implementados en 07_professional_directory_rpc.sql:

CREATE OR REPLACE FUNCTION approve_professional_account(
    p_profile_id BIGINT,
    p_admin_id UUID
) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reject_professional_account(
    p_profile_id BIGINT,
    p_admin_id UUID,
    p_reason TEXT
) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION toggle_professional_account_status(
    p_profile_id BIGINT,
    p_admin_id UUID,
    p_status TEXT
) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### HU-5.5: Usuarios y roles

**User Story:** Como administrador, quiero gestionar accesos y roles de usuarios.

**Criterios de Aceptación:**

- [x] Listado de usuarios con búsqueda y filtros por rol/estado.
- [x] Edición de rol principal (user/b2b/admin) con jerarquia.
- [x] Suspender/Reactivar usuarios (soft delete con `deleted_at`).
- [ ] Invitacion o creacion manual de usuarios.

**Frontend:** `src/features/admin/users/pages/AdminUsersPage.tsx`

**Supabase (`06_complementary`):**

```sql
-- Tablas base
-- profiles, roles, profile_roles
-- (Opcional) Vista de auth.users para email
```

---

### HU-5.6: Gestión de cupones y promociones

**User Story:** Como administrador, quiero crear y controlar cupones de descuento.

**Criterios de Aceptación:**

- [x] CRUD de cupones con tipos (porcentaje, monto fijo, envio gratis).
- [x] Activar/Desactivar cupones con confirmacion.
- [x] Filtros por estado, tipo y busqueda por codigo.
- [x] Visibilidad de usos y limites.

**Frontend:** `src/features/admin/coupons/pages/AdminCouponsPage.tsx`

**Supabase (`02_store_ecommerce`):**

```sql
-- Tabla coupons
```

---

### HU-5.7: CMS de contenido y legal

**User Story:** Como administrador, quiero editar el contenido publico sin depender de desarrollo.

**Criterios de Aceptación:**

- [x] Configuracion de landing (hero, beneficios, how it works, trust, FAQ, CTA).
- [x] Configuracion de pagina Nosotros (hero, mision/vision, timeline).
- [x] Blog CMS: categorias, posts, publicar/despublicar, articulo principal.
- [x] FAQs: categorias y preguntas con orden.
- [x] Documentos legales (privacy, terminos, devoluciones, envios) en Markdown.
- [x] Pickers de productos, testimonios y FAQs para la home.

**Frontend:**
`src/features/admin/content/pages/AdminContentLandingPage.tsx`,
`src/features/admin/content/pages/AdminContentAboutPage.tsx`,
`src/features/admin/content/pages/AdminContentBlogPage.tsx`,
`src/features/admin/content/pages/AdminContentFaqPage.tsx`,
`src/features/admin/content/pages/AdminContentLegalPage.tsx`

**Supabase:**

```sql
-- home_page_config, about_page_config
-- blog_categories, blog_posts
-- faq_categories, faqs
-- content_pages
-- products, testimonials (pickers)
```

---

### HU-5.8: Gestión de reclamos (Admin)

**User Story:** Como administrador, quiero gestionar reclamos del Libro de Reclamaciones.

**Criterios de Aceptación:**

- [ ] Listado de reclamos con filtros por estado.
- [ ] Ver detalle completo del reclamo.
- [ ] Registrar respuesta y cambio de estado.
- [ ] Exportar reporte de reclamos.

**Frontend:** `src/features/admin/claims/pages/AdminClaimsPage.tsx`

**Supabase (`04_legal_compliance`):**

```sql
-- Tabla claims
```

---

### HU-5.9: Panel administrativo

**User Story:** Como administrador, quiero un panel de inicio con accesos directos.

**Criterios de Aceptación:**

- [x] Vista de bienvenida con accesos rapidos a modulos clave.
- [x] Resumen visual de tareas del dia.
- [ ] Indicadores conectados a datos reales.

**Frontend:** `src/features/admin/dashboard/pages/AdminDashboardPage.tsx`

---

## Módulo 6: Complementarios

### HU-6.1: Autenticación y Perfiles

**User Story:** Como usuario, quiero crear cuenta y gestionar mi perfil.

**Criterios de Aceptación:**

- [ ] Registro con email/contraseña (Supabase Auth)
- [ ] Login con email/contraseña
- [ ] Login social con Google OAuth
- [ ] Flujo de recuperación de contraseña por email
- [ ] Verificación de email obligatoria
- [ ] Crear perfil automáticamente al registrarse
- [ ] Asignar rol 'user' por defecto
- [ ] username obligatorio en registro por email (solo `[a-z0-9_]`, 3-30 chars)
- [ ] username auto-generado (`user_` + hex) en registro con Google OAuth
- [ ] full_name y username NOT NULL en tabla profiles
- [ ] username UNIQUE — no puede repetirse entre usuarios
- [ ] Página de perfil con datos personales editables
- [ ] Editar username con validación (lowercase, sin espacios, UNIQUE)
- [ ] Editar full_name (obligatorio)
- [ ] Subir foto de perfil (avatar)
- [ ] Agregar tipo y número de documento
- [ ] Gestionar múltiples direcciones de envío
- [ ] Ver historial de pedidos

**Frontend:** `src/features/security/`, `src/features/profile/`

**Supabase (`06_complementary`):**

```sql
-- Perfil de usuario (Identidad independiente)
CREATE TABLE profiles (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para filtrar perfiles activos eficientemente
CREATE INDEX idx_perf_profiles_active ON profiles (user_id) WHERE deleted_at IS NULL;

-- Roles
CREATE TABLE roles (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT
);

INSERT INTO roles (id, name, description) VALUES
    (1, 'admin', 'Administrador principal'),
    (2, 'professional', 'Profesional en Mascotas'),
    (3, 'user', 'Usuario estándar o Dueño de Mascota');

-- Relación perfiles-roles
CREATE TABLE profile_roles (
    profile_id BIGINT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (profile_id, role_id)
);

CREATE OR REPLACE FUNCTION handle_new_user_registration()
RETURNS TRIGGER AS $$
    -- Resuelve username y full_name desde metadata, auto-genera si OAuth
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user_registration();

-- Funciones para manejo y validación de roles en RLS
CREATE OR REPLACE FUNCTION auth_has_role(p_required_role TEXT)
RETURNS BOOLEAN AS $$
    -- Comprueba si auth.uid() tiene el rol especificado
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_roles()
RETURNS JSONB AS $$
    -- Devuelve el array de roles asignados al usuario actual
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Módulo 7: Directorio Profesional

### HU-7.1: Landing Page del Directorio Profesional

**User Story:** Como visitante o dueño de mascota, quiero ver una página de inicio (Landing Page) atractiva del directorio con herramientas de búsqueda rápida, categorías y propuesta de valor para entender cómo encontrar y agendar con el profesional adecuado, además de una invitación para que nuevos profesionales se unan.

**Criterios de Aceptación:**

- [ ] Hero banner dinámico con buscador principal integrado (Especialidad y Lugar) y botón "Buscar".
- [ ] Renderizado de imágenes/tarjetas superpuestas de profesionales destacados en el hero.
- [ ] Sección de categorías de ayuda (ej. Veterinaria general, Nutrición, Grooming, etc.) dinámicas.
- [ ] Sección de propuesta de valor "¿Cómo cuidamos la calidad de los profesionales?" con puntos clave ilustrados.
- [ ] Sección CTA inferior "¿Eres profesional y quieres aparecer en +Kot?" para invitar a nuevos registros.
- [ ] Toda la información de la landing (títulos, textos, imágenes, categorías mostradas) debe ser configurable mediante secciones JSONB.
- [ ] Loading skeleton mientras cargan los datos dinámicos.
- [ ] Mobile-first responsive acorde al diseño provisto.

**Frontend:** `src/features/directory/pages/DirectoryLandingPage.tsx`, `directoryLandingService.ts`

**Supabase (`07_professional_directory`):**

```sql
-- Configuración de Landing Page del Directorio Profesional
CREATE TABLE professional_page_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    
    -- 1er Bloque: Hero y Buscador Rápido
    hero_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 2do Bloque: Categorías / "Qué tipo de ayuda necesitas"
    categories_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 3er Bloque: Propuesta de Valor
    value_proposition_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- 4to Bloque: Captación de Profesionales (CTA)
    professional_cta_section JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Datos iniciales (Seed) para el Landing de Directorio
INSERT INTO professional_page_config (
    id,
    hero_section,
    categories_section,
    value_proposition_section,
    professional_cta_section
) VALUES (
    1,
    '{
        "title": "Encuentra profesionales para tu perro, por especialidad y zona.",
        "subtitle": "Busca, compara y elige con más claridad, sin perder tiempo preguntando a ciegas.",
        "search_placeholders": {
            "specialty": "Especialidad",
            "location": "Lugar"
        },
        "search_button_text": "Buscar",
        "hero_images": [
            "https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&q=80&w=400&h=600",
            "https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&q=80&w=400&h=600",
            "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=400&h=600"
        ]
    }'::jsonb,
    '{
        "title": "¿Qué tipo de ayuda necesitas hoy?",
        "subtitle": "Cuando no tienes el nombre exacto de lo que necesitas, las categorías te guían. Entra a una categoría, filtra por tu zona y encuentra opciones alineadas a tu caso."
    }'::jsonb,
    '{
        "title": "¿Cómo cuidamos la calidad de los profesionales?",
        "image_url": "https://images.unsplash.com/photo-1599443015574-be5fe8a05783?auto=format&fit=crop&q=80&w=800",
        "points": [
            {
                "number": "1",
                "title": "Perfiles con información útil",
                "description": "Cada perfil está pensado para ayudarte a comparar sin adivinar: qué hace, cómo atiende y lo necesario para decidir con claridad antes de contactar."
            },
            {
                "number": "2",
                "title": "Orden por especialidad y zona",
                "description": "Encontrar el profesional correcto no debería tomarte horas. Al buscar por especialidad y ubicación reduces ruido y llegas más rápido a opciones alineadas a tu caso."
            },
            {
                "number": "3",
                "title": "Señales de confianza visibles",
                "description": "A medida que el directorio crece, incorporamos señales que suman contexto real, como información más completa y reseñas cuando están disponibles, para que elijas con más seguridad."
            }
        ]
    }'::jsonb,
    '{
        "title": "¿Eres profesional y quieres aparecer en +Kot?",
        "description": "Postula en menos de 2 minutos y crea tu perfil para que dueños de perros te encuentren por especialidad y zona. Te avisaremos cuando tu perfil esté publicado y listo para recibir consultas.",
        "cta_text": "Postular",
        "cta_link": "/professionals/register",
        "image_url": "https://images.unsplash.com/photo-1537151608804-ea2f1cb0464f?auto=format&fit=crop&q=80&w=300"
    }'::jsonb
);
```

---

### HU-7.2: Perfil Público y Registro del Profesional

**User Story:** Como profesional de mascotas, quiero registrarme, acreditar mi identidad y crear un perfil detallado de mi práctica en un solo lugar para que los dueños me encuentren y pueda acceder a los descuentos exclusivos.

**Criterios de Aceptación:**

- [ ] Formulario unificado de registro: Datos legales (RUC, Empresa) + Datos del Perfil (Título profesional, y selección de primera Especialidad/Servicio).
- [ ] Estado de validación por parte de MasKot (Pendiente, Aprobado, Rechazado).
- [ ] Una vez "Aprobado", el perfil puede publicarse (`is_published = true`) y el profesional obtiene automáticamente los precios especiales en la tienda.
- [ ] Panel de gestión: Configuración de Nombre público, Título (Ej: Médico Veterinario), y gestión de su Catálogo de Servicios (asignando a qué Especialidad del sistema pertenece cada servicio).
- [ ] Experiencia y Resumen (Texto descriptivo + lista de condiciones tratadas).
- [ ] Lista de Servicios y Precios "Desde" (Ej: "Consulta presencial desde S/ 60.00").
- [ ] Galería de 4-6 fotos para generar confianza (clínica, equipos, espacio).
- [ ] Ubicación: Dirección exacta vinculada a coordenadas (lat/lng) para el mapa.
- [ ] Sistema de testimonios de tutores con rating (1-5 estrellas).
- [ ] Previsualización de disponibilidad de calendario.

**Frontend:** `src/features/professionals/pages/ProfessionalRegistrationProfile.tsx`, `ProfessionalProfilePublicPage.tsx`

**Supabase (`07_professional_directory`):**

```sql
CREATE TYPE professional_profile_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');

-- Catálogo Maestro de Especialidades (Administrado por MasKot)
CREATE TABLE professional_specialties (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    icon_url TEXT,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Perfil unificado del profesional (Datos legales + Directorio Público)
CREATE TABLE professional_profiles (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    profile_id BIGINT UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- [1] Datos Legales para validación y facturación
    business_name TEXT NOT NULL,
    ruc TEXT NOT NULL UNIQUE CHECK (LENGTH(ruc) = 11),
    legal_document_url TEXT,
    
    -- [2] Estado de Validación MasKot
    status professional_profile_status NOT NULL DEFAULT 'pending',
    approved_by BIGINT REFERENCES profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- [3] Datos Públicos del Directorio
    public_name TEXT NOT NULL, 
    title TEXT NOT NULL, 
    experience_summary TEXT,
    base_price NUMERIC(10, 2),
    consultation_types TEXT[] DEFAULT '{}',
    
    -- [4] Multimedia
    profile_photo_url TEXT,
    gallery_urls TEXT[] DEFAULT '{}',
    
    -- [5] Localización para Búsqueda y Mapa
    address_text TEXT NOT NULL,
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    
    -- [6] Métricas de Testimonios
    average_rating NUMERIC(3, 2) DEFAULT 0.00,
    total_reviews INTEGER DEFAULT 0,
    
    -- Visibilidad
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Servicios ofrecidos por el profesional (Tabla Intermedia entre Especialidad y Profesional)
CREATE TABLE professional_services (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    professional_profile_id BIGINT NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    professional_specialty_id BIGINT NOT NULL REFERENCES professional_specialties(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Semilla de Especialidades (Catálogo Central)
INSERT INTO professional_specialties (name, slug, display_order) VALUES
('Veterinaria General', 'veterinaria-general', 10),
('Nutrición', 'nutricion', 20),
('Odontología', 'odontologia', 30),
('Dermatología', 'dermatologia', 40),
('Grooming y Estética', 'grooming', 50),
('Entrenamiento', 'entrenamiento', 60),
('Rehabilitación', 'rehabilitacion', 70);

-- RPC: Solicitar ser profesional
CREATE OR REPLACE FUNCTION create_professional_account_request(
    p_business_name TEXT,
    p_ruc TEXT,
    p_public_name TEXT,
    p_title TEXT,
    p_address_text TEXT,
    p_specialty_id BIGINT
) RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Obtener catálogo B2B
CREATE OR REPLACE FUNCTION get_professional_products(p_profile_id BIGINT)
RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Validar chequeo de beneficios
CREATE OR REPLACE FUNCTION check_professional_eligibility(p_profile_id BIGINT)
RETURNS JSONB AS $$ $$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### HU-7.3: Búsqueda y Directorio Interactivo (Mapa)

**User Story:** Como dueño de mascota, quiero buscar profesionales cercanos e idóneos para agendar la atención que necesita mi mascota.

**Integración de Mapas:** Google Maps Platform (Maps JavaScript API + Places API).  
**Variable de entorno:** `VITE_GOOGLE_MAPS_API_KEY`  
**Dependencia frontend:** `@vis.gl/react-google-maps`

**Criterios de Aceptación:**

- [ ] Barra de filtros: Categoría (specialty), Etiqueta (consultation_type), Ordenar por (rating/precio/nombre), Buscar (texto libre).
- [ ] Chips de filtros activos removibles.
- [ ] Split-View (Desktop) y Toggle (Mobile): 
  - [ ] Lado izquierdo: Listado de tarjetas de profesionales.
  - [ ] Lado derecho: Mapa interactivo (Google Maps) con pins por profesional.
- [ ] Tarjeta de Profesional: Foto, public_name, title, average_rating con estrellas, address_text, consultation_types, base_price.
- [ ] Mapa con markers, bounds automáticos, botón "Ampliar mapa", InfoWindow en click.

**Frontend:** `src/features/directory/pages/SpecialistsPage.tsx`  
**Componentes:** `SpecialistsFilterBar.tsx`, `ProfessionalCard.tsx`, `GoogleMapView.tsx`

**Supabase (`07_professional_directory`):**

```sql
-- La búsqueda en el directorio se hace mayormente consumiendo directamente desde supabase con filtros.
```

---

### HU-7.4: Herramienta de Agendamiento de Citas

**User Story:** Como usuario, quiero ver la información completa de un profesional y reservar una franja horaria para atender a mi mascota.

**Criterios de Aceptación:**

- [ ] Bloque lateral tipo Widget "Booking" en la ficha del profesional.
- [ ] Selector principal de Motivo de Citas.
- [ ] Grilla de Horarios interactiva con franjas de disponibilidad.
- [ ] Sistema de Testimonios (solo clientes que cruzaron por la pasarela de citas completadas).

**Frontend:** `src/features/directory/pages/ProfessionalDetailPage.tsx`, `BookingWidget.tsx`

**Supabase (`07_professional_directory`):**

```sql
CREATE TYPE professional_appointment_status AS ENUM ('pending', 'confirmed', 'completed', 'cancelled', 'no_show');

-- Horarios disponibles
CREATE TABLE professional_availability (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    professional_profile_id BIGINT NOT NULL REFERENCES professional_profiles(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Citas/Reservas agendadas
CREATE TABLE professional_appointments (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    professional_profile_id BIGINT NOT NULL REFERENCES professional_profiles(id),
    client_profile_id BIGINT NOT NULL REFERENCES profiles(id),
    service_id BIGINT REFERENCES professional_services(id),
    
    appointment_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    
    is_first_visit BOOLEAN DEFAULT TRUE,
    status professional_appointment_status DEFAULT 'pending',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Testimonios validados
CREATE TABLE professional_reviews (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    professional_appointment_id BIGINT UNIQUE REFERENCES professional_appointments(id),
    professional_profile_id BIGINT NOT NULL REFERENCES professional_profiles(id),
    client_profile_id BIGINT NOT NULL REFERENCES profiles(id),
    
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### HU-7.5: Beneficios Tienda para Profesionales (Descuentos)

**User Story:** Como profesional habilitado en el Directorio, quiero acceder automáticamente a precios mayoristas al comprar en la tienda MasKot.

**Criterios de Aceptación:**

- [ ] Si el usuario tiene un perfil asociado en `professional_profiles` con `status = 'approved'`, la tienda renderiza la vista mayorista.
- [ ] Aplicación de `professional_discount_pct` extraído de la tabla `products`.
- [ ] Formatos Industriales compatibles dinámicamente con el descuento.

**Frontend:** `src/features/store/hooks/useProfessionalDiscount.ts`

**Supabase (`07_professional_directory`):**

```sql
-- Lógica inyectada en las Queries de Catálogo y Carrito evaluando el rol del perfil autenticado,
-- multiplicando "variant_price * (1 - (professional_discount_pct / 100))"
```

---

## 📊 Estructura de Archivos SQL

```text
supabase/
├── 01_identity_landings/
│   ├── 01_identity_landings_rpc.sql       # Fase 2
│   ├── 01_identity_landings_perf.sql      # Fase 3
│   └── 01_identity_landings_rls.sql       # Fase 3
├── 02_store_ecommerce/
│   ├── 02_store_ecommerce_rpc.sql
│   ├── 02_store_ecommerce_perf.sql
│   └── 02_store_ecommerce_rls.sql
├── 03_checkout_subscriptions/
│   ├── 03_checkout_subscriptions_rpc.sql
│   ├── 03_checkout_subscriptions_perf.sql
│   └── 03_checkout_subscriptions_rls.sql
├── 04_legal_compliance/
│   ├── 04_legal_compliance_rpc.sql
│   ├── 04_legal_compliance_perf.sql
│   └── 04_legal_compliance_rls.sql
├── 05_admin_backoffice/
│   ├── 05_admin_backoffice_rpc.sql
│   ├── 05_admin_backoffice_perf.sql
│   └── 05_admin_backoffice_rls.sql
├── 06_complementary/
│   ├── 06_complementary_rpc.sql
│   ├── 06_complementary_perf.sql
│   └── 06_complementary_rls.sql
└── 07_b2b_professional/
    ├── 07_b2b_professional_rpc.sql
    ├── 07_b2b_professional_perf.sql
    └── 07_b2b_professional_rls.sql
```

---

## 🚀 Priorización MoSCoW (MVP)

### Must Have (MVP)

- HU-1.1: Home Page
- HU-2.1, 2.2, 2.3: Catálogo y Carrito
- **HU-2.4: Calculadora de Ración** ⭐
- HU-3.1: Checkout simplificado
- HU-4.1, 4.2: Legal + Libro Reclamaciones
- HU-6.1: Autenticación
- **HU-7.2, 7.3: Registro y Catálogo B2B** ⭐

### Should Have

- HU-3.2: Gestión de Suscripción
- HU-5.1, 5.2, 5.3: Admin básico
- **HU-5.4: Gestión Cuentas B2B** ⭐
- HU-6.2: Notificaciones

### Could Have

- HU-1.2, 1.3: Nosotros y Blog
- **HU-7.1: Landing Page del Directorio Profesional** ⭐
- **HU-7.4: Formatos Industriales** ⭐

---

*MasKot - MVP Simplificado - Modelo AltuDog*  
*Fase 1: Definición & Arquitectura*  
*Última actualización: 2026-02-16*
