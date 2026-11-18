package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;

/** Funcionalidad: registro de productos y reporte de precios. */
@QuarkusTest
class RegistroApiTest {

    @Test
    void registraProductoNuevoYLoReutilizaSiYaExiste() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);

        long id = given().contentType(ContentType.JSON).body(TestApi.leche(s, u, "Éxito", "Éxito Chapinero " + s, "Bogotá", 4500))
                .when().post("/api/productos").then().statusCode(201)
                .body("productoNuevo", equalTo(true)).extract().jsonPath().getLong("productoId");

        // Mismo producto con otra capitalización y espacios extra: NO se duplica
        Map<String, Object> repetido = TestApi.leche(s, u, "D1", "D1 Suba " + s, "Bogotá", 3900);
        repetido.put("nombre", "  LECHE   ENTERA " + s + " ");
        repetido.put("marca", " alquería ");
        repetido.put("presentacion", "BOLSA");
        given().contentType(ContentType.JSON).body(repetido)
                .when().post("/api/productos").then().statusCode(200)
                .body("productoNuevo", equalTo(false)).body("productoId", equalTo((int) id));

        given().queryParam("q", s).when().get("/api/productos").then().body("total", equalTo(1));
    }

    @Test
    void otraCantidadOPresentacionEsOtroProducto() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long a = TestApi.registrar(TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500));
        Map<String, Object> grande = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 8000);
        grande.put("cantidad", 2200);
        long b = TestApi.registrar(grande);
        assertEquals(false, a == b);
    }

    @Test
    void agregaUnNuevoPrecioAUnProductoExistente() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long id = TestApi.registrar(TestApi.leche(s, u, "Éxito", "Sede A " + s, "Bogotá", 4500));
        TestApi.agregarPrecio(id, u, "Ara", "Ara Kennedy " + s, "Bogotá", 4100, LocalDate.now().minusDays(3));
        given().when().get("/api/productos/" + id + "/historial").then().statusCode(200).body("size()", equalTo(2));
    }

    @Test
    void guardaYEntregaLaFotografia() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        Map<String, Object> body = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        body.put("fotoBase64", "data:image/jpeg;base64," + TestApi.jpegBase64(40));
        long id = TestApi.registrar(body);

        byte[] foto = given().when().get("/api/productos/" + id + "/foto").then().statusCode(200)
                .contentType("image/jpeg").extract().asByteArray();
        assertEquals(40, foto.length);
        given().when().get("/api/productos/" + id).then().body("tieneFoto", equalTo(true));
    }

    @Test
    void completaLaFotoSiElProductoExistenteNoTenia() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long id = TestApi.registrar(TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500));
        given().when().get("/api/productos/" + id + "/foto").then().statusCode(404);

        Map<String, Object> conFoto = TestApi.leche(s, u, "D1", "D1 " + s, "Bogotá", 3900);
        conFoto.put("fotoBase64", TestApi.jpegBase64(30));
        assertEquals(id, TestApi.registrar(conFoto));
        given().when().get("/api/productos/" + id + "/foto").then().statusCode(200);
    }

    @Test
    void rechazaFotosInvalidas() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        Map<String, Object> noImagen = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        noImagen.put("fotoBase64", java.util.Base64.getEncoder().encodeToString("esto no es una imagen, es texto".getBytes()));
        given().contentType(ContentType.JSON).body(noImagen).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("JPEG"));

        Map<String, Object> pesada = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        pesada.put("fotoBase64", TestApi.jpegBase64(1_100_000));
        given().contentType(ContentType.JSON).body(pesada).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("1 MB"));

        Map<String, Object> basura = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        basura.put("fotoBase64", "@@@@no-es-base64@@@@");
        given().contentType(ContentType.JSON).body(basura).when().post("/api/productos").then().statusCode(400);

        given().queryParam("q", s).when().get("/api/productos").then().body("total", equalTo(0));
    }

    @Test
    void validaLosCamposObligatoriosYSusLimites() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        String[] campos = {"nombre", "marca", "categoria", "presentacion", "unidad", "almacen", "sede", "ciudad"};
        for (String campo : campos) {
            Map<String, Object> body = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
            body.put(campo, "   ");
            given().contentType(ContentType.JSON).body(body).when().post("/api/productos").then().statusCode(400);
        }
        Map<String, Object> sinUsuario = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        sinUsuario.remove("usuarioId");
        given().contentType(ContentType.JSON).body(sinUsuario).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("identificarse"));

        Map<String, Object> cantidad0 = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        cantidad0.put("cantidad", 0);
        given().contentType(ContentType.JSON).body(cantidad0).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("cantidad"));

        Map<String, Object> unidad = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        unidad.put("unidad", "galon");
        given().contentType(ContentType.JSON).body(unidad).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("unidad"));

        Map<String, Object> largo = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 4500);
        largo.put("nombre", "x".repeat(161));
        given().contentType(ContentType.JSON).body(largo).when().post("/api/productos").then().statusCode(400);
    }

    @Test
    void validaElPrecioYLaFecha() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        for (int precio : new int[]{0, -5, 100_000_001}) {
            given().contentType(ContentType.JSON).body(TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", precio))
                    .when().post("/api/productos").then().statusCode(400).body("error", containsString("precio"));
        }
        Map<String, Object> futura = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 1000);
        futura.put("fecha", LocalDate.now().plusDays(5).toString());
        given().contentType(ContentType.JSON).body(futura).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("futura"));

        Map<String, Object> antigua = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 1000);
        antigua.put("fecha", LocalDate.now().minusDays(800).toString());
        given().contentType(ContentType.JSON).body(antigua).when().post("/api/productos").then()
                .statusCode(400).body("error", containsString("2 años"));
    }

    @Test
    void rechazaUsuariosYProductosInexistentes() {
        String s = TestApi.sufijo();
        given().contentType(ContentType.JSON).body(TestApi.leche(s, 999_999_999L, "Éxito", "Sede " + s, "Bogotá", 1000))
                .when().post("/api/productos").then().statusCode(400);

        long u = TestApi.crearUsuario(s);
        given().contentType(ContentType.JSON)
                .body(Map.of("almacen", "Ara", "sede", "X", "ciudad", "Cali", "precioCop", 1000, "usuarioId", u))
                .when().post("/api/productos/999999999/precios").then().statusCode(404);
    }

    @Test
    void unRegistroFallidoNoDejaDatosAMedias() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        Map<String, Object> futura = TestApi.leche(s, u, "Éxito", "Sede " + s, "Bogotá", 1000);
        futura.put("fecha", LocalDate.now().plusDays(10).toString());
        given().contentType(ContentType.JSON).body(futura).when().post("/api/productos").then().statusCode(400);
        // La transacción se revierte: el producto no quedó creado
        given().queryParam("q", s).when().get("/api/productos").then().body("total", equalTo(0));
    }
}
