-- Amplia a geofence do QR de 100 m para 500 m, alinhada à política de acesso
-- e ao requisito de operação em prédios com sinal de GPS instável.
ALTER TABLE "AccessLocation" DROP CONSTRAINT IF EXISTS "AccessLocation_radiusMeters_check";
ALTER TABLE "AccessLocation"
ADD CONSTRAINT "AccessLocation_radiusMeters_check"
CHECK ("radiusMeters" BETWEEN 1 AND 500);
