-- ============================================================================
-- Componente: Notifications
-- Módulo: 08_notifications
-- Descripción: Tabla principal y políticas de RLS para el sistema de notificaciones universales.
-- ============================================================================

-- Tabla de Notificaciones
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- ej: 'appointment_request', 'appointment_accepted', 'order_placed'
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    reference_type TEXT, -- ej: 'professional_appointment_requests', 'orders'
    reference_id TEXT, -- ID de referencia en texto para permitir enteros o UUIDs
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Índices de búsqueda
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_notifications_type ON public.notifications(type);

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Política de Lectura (Select): El usuario solo puede ver sus propias notificaciones
CREATE POLICY "Users can view their own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

-- Política de Actualización (Update): El usuario solo puede actualizar sus notificaciones (marcar leídas)
CREATE POLICY "Users can update their own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Política de Borrado (Delete): El usuario puede borrar sus notificaciones
CREATE POLICY "Users can delete their own notifications"
    ON public.notifications FOR DELETE
    USING (auth.uid() = user_id);

-- Opcional: Solo servicios con service_role o webhooks internos insertan, pero si hay necesidad:
CREATE POLICY "Service Role can insert notifications"
    ON public.notifications FOR INSERT
    WITH CHECK (true); -- Depende de cómo inserte supabase. Generalmente Triggers usando SECURITY DEFINER ignoran RLS.
