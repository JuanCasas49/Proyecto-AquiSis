package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;

/** Funcionalidad: identificación de usuarios (nombre + correo). */
@QuarkusTest
class UsuarioApiTest {

    @Test
    void registraUnUsuarioNuevo() {
        String s = TestApi.sufijo();
        given().contentType(ContentType.JSON).body(Map.of("nombre", "Ana " + s, "email", "ana" + s + "@example.com"))
                .when().post("/api/usuarios").then().statusCode(200)
                .body("nombre", equalTo("Ana " + s)).body("email", equalTo("ana" + s + "@example.com"));
    }

    @Test
    void elMismoCorreoRecuperaElMismoUsuarioSinImportarMayusculas() {
        String s = TestApi.sufijo();
        long id1 = given().contentType(ContentType.JSON).body(Map.of("nombre", "Luis " + s, "email", "luis" + s + "@example.com"))
                .when().post("/api/usuarios").then().statusCode(200).extract().jsonPath().getLong("id");
        long id2 = given().contentType(ContentType.JSON).body(Map.of("nombre", "Luis P " + s, "email", "LUIS" + s + "@EXAMPLE.com"))
                .when().post("/api/usuarios").then().statusCode(200).extract().jsonPath().getLong("id");
        assertEquals(id1, id2);
    }

    @Test
    void rechazaCorreosInvalidos() {
        for (String correo : new String[]{"no-es-correo", "a@b", "sin arroba.com", ""}) {
            given().contentType(ContentType.JSON).body(Map.of("nombre", "Ana Gómez", "email", correo))
                    .when().post("/api/usuarios").then().statusCode(400);
        }
    }

    @Test
    void rechazaNombresVaciosOMuyCortos() {
        given().contentType(ContentType.JSON).body(Map.of("nombre", "A", "email", "a@example.com"))
                .when().post("/api/usuarios").then().statusCode(400).body("error", containsString("nombre"));
        given().contentType(ContentType.JSON).body(Map.of("nombre", "   ", "email", "a@example.com"))
                .when().post("/api/usuarios").then().statusCode(400);
    }
}
