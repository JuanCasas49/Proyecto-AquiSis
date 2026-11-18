package org.acme;

import io.quarkus.test.junit.QuarkusTestProfile;

import java.util.Map;

/** Activa la regla de HU-08: los precios reportados quedan "pendiente" hasta que un moderador los valide. */
public class ValidacionActivaProfile implements QuarkusTestProfile {

    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of("app.precios.validacion-requerida", "true");
    }
}
