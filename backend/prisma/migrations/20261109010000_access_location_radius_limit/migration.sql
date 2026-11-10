ALTER TABLE "AccessLocation"
ADD CONSTRAINT "AccessLocation_radiusMeters_check"
CHECK ("radiusMeters" BETWEEN 1 AND 100);
