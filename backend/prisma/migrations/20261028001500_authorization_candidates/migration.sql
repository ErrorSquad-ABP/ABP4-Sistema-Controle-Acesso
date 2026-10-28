-- DT-17: a decisao de acesso busca e bloqueia apenas a primeira autorizacao
-- utilizavel do usuario no local (ordem de escolha: endsAt, id) e, quando nao ha
-- nenhuma, apenas a primeira linha para o motivo da negativa. O indice composto
-- cobre os dois casos com igualdade em userId/locationId e ordem em endsAt/id.
CREATE INDEX "Authorization_userId_locationId_endsAt_id_idx" ON "Authorization"("userId", "locationId", "endsAt", "id");
