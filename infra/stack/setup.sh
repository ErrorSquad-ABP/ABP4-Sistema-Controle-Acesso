set -e
export PGPASSWORD=abp4
psql -h postgres -U abp4 -d abp4 -v ON_ERROR_STOP=1 -v lat="$GEO_LAT" -v lon="$GEO_LON" <<'SQL'
INSERT INTO "Terminal" (id, "locationId", active, "updatedAt")
VALUES ('terminal-dev-01','a1000000-0000-4000-8000-000000000003', true, now())
ON CONFLICT (id) DO UPDATE SET active = true;
UPDATE "AccessLocation" SET latitude = :lat, longitude = :lon
WHERE id = 'a1000000-0000-4000-8000-000000000003';
SELECT id, "locationId", active FROM "Terminal";
SELECT id, latitude, longitude, "radiusMeters" FROM "AccessLocation";
SQL
