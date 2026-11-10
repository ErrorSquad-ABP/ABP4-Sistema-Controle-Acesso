#pragma once

// Fixture sintetica: o teste nao depende do PEM real de include/mqtt_ca.h.
namespace mqtt_ca {
constexpr char kRootPem[] =
    "-----BEGIN CERTIFICATE-----\nFIXTURE-DE-TESTE\n-----END CERTIFICATE-----\n";
}  // namespace mqtt_ca
