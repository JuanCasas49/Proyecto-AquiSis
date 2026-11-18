package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.TestProfile;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * HU-08: registro colaborativo de precios con evidencia fotográfica. El precio queda "pendiente"
 * hasta que un moderador lo valida; solo los validados cuentan en catálogo, comparador y listas.
 */
@QuarkusTest
@TestProfile(ValidacionActivaProfile.class)
class RegistroColaborativoApiTest {

    @Inject
    DataSource dataSource;

    private long moderador(String s) {
        long id = TestApi.crearUsuario(s + "m");
        try (Connection c = dataSource.getConnection(); PreparedStatement ps = c.prepareStatement("UPDATE usuarios SET rol = 'moderador' WHERE id = ?")) {
            ps.setLong(1, id);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new IllegalStateException(e);
        }
        return id;
    }

    /** Registra un producto nuevo con evidencia y devuelve la respuesta. */
    private JsonPath registrar(String s, long usuario, String almacen, int precio, boolean conFoto) {
        Map<String, Object> body = TestApi.leche(s, usuario, almacen, almacen + " Sede " + s, "Bogotá", precio);
        if (conFoto) {
            body.put("fotoBase64", TestApi.jpegBase64(40));
        }
        return given().contentType(ContentType.JSON).body(body).when().post("/api/productos").then().extract().jsonPath();
    }

    private static JsonPath nuevoPrecio(long producto, long usuario, String almacen, String sede, int precio, String evidencia) {
        Map<String, Object> body = new HashMap<>();
        body.put("almacen", almacen);
        body.put("sede", sede);
        body.put("ciudad", "Bogotá");
        body.put("precioCop", precio);
        body.put("usuarioId", usuario);
        if (evidencia != null) {
            body.put("evidenciaBase64", evidencia);
        }
        return given().contentType(ContentType.JSON).body(body).when().post("/api/productos/" + producto + "/precios")
                .then().statusCode(201).extract().jsonPath();
    }

    @Test
    void elPrecioReportadoQuedaPendienteYNoEsOficial() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        JsonPath r = registrar(s, u, "Éxito", 4500, true);
        assertEquals("pendiente", r.getString("estado"));
        assertTrue(r.getBoolean("productoNuevo"));
        long id = r.getLong("productoId");

        // Catálogo: el producto existe pero sin precio oficial; informa que hay uno pendiente
        JsonPath catalogo = given().queryParam("q", s).when().get("/api/productos").then().statusCode(200).extract().jsonPath();
        assertEquals(1, catalogo.getInt("total"));
        assertEquals(1, catalogo.getInt("items[0].nPendientes"));
        assertEquals(0, catalogo.getInt("items[0].nSedes"));
        assertTrue(catalogo.get("items[0].precioMin") == null);
        // Comparador: sin precios validados
        given().when().get("/api/productos/" + id + "/comparacion").then().statusCode(200).body("precios.size()", equalTo(0));
        // Los filtros de precio o almacén usan solo precios validados
        given().queryParam("q", s).queryParam("precioMin", 1).when().get("/api/productos").then().body("total", equalTo(0));
        // Historial: el reporte aparece con su estado y evidencia
        JsonPath h = given().when().get("/api/productos/" + id + "/historial").then().statusCode(200).extract().jsonPath();
        assertEquals("pendiente", h.getString("[0].estado"));
        assertTrue(h.getBoolean("[0].tieneEvidencia"));
    }

    @Test
    void laEvidenciaEsOpcionalPeroSePuedeAdjuntar() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        JsonPath con = registrar(s, u, "Éxito", 4500, true);
        long conEvidencia = con.getLong("reporteId");
        byte[] foto = given().when().get("/api/precios/" + conEvidencia + "/evidencia").then().statusCode(200)
                .contentType("image/jpeg").extract().asByteArray();
        assertEquals(40, foto.length);

        // Otro reporte sin foto: es válido y queda pendiente igualmente
        JsonPath sin = nuevoPrecio(con.getLong("productoId"), u, "D1", "D1 Sede " + s, 3900, null);
        assertEquals("pendiente", sin.getString("estado"));
        given().when().get("/api/precios/" + sin.getLong("reporteId") + "/evidencia").then().statusCode(404);

        // Evidencia específica del reporte (distinta de la foto del producto)
        JsonPath otra = nuevoPrecio(con.getLong("productoId"), u, "Ara", "Ara Sede " + s, 3800, TestApi.jpegBase64(25));
        assertEquals(25, given().when().get("/api/precios/" + otra.getLong("reporteId") + "/evidencia").then()
                .statusCode(200).extract().asByteArray().length);
    }

    @Test
    void rechazaEvidenciasInvalidas() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long id = registrar(s, u, "Éxito", 4500, false).getLong("productoId");
        for (String malo : new String[]{java.util.Base64.getEncoder().encodeToString("no soy una imagen, solo texto".getBytes()),
                TestApi.jpegBase64(1_100_000)}) {
            given().contentType(ContentType.JSON)
                    .body(Map.of("almacen", "A", "sede", "S", "ciudad", "Bogotá", "precioCop", 100, "usuarioId", u, "evidenciaBase64", malo))
                    .when().post("/api/productos/" + id + "/precios").then().statusCode(400);
        }
        assertEquals(1, given().when().get("/api/productos/" + id + "/historial").then().extract().jsonPath().getList("$").size());
    }

    @Test
    void elUsuarioConsultaSusReportesConSuEstado() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long id = registrar(s, u, "Éxito", 4500, true).getLong("productoId");
        nuevoPrecio(id, u, "D1", "D1 Sede " + s, 3900, null);

        JsonPath todos = given().when().get("/api/usuarios/" + u + "/reportes").then().statusCode(200).extract().jsonPath();
        assertEquals(2, todos.getList("$").size());
        assertTrue(todos.getList("estado").stream().allMatch("pendiente"::equals));
        assertEquals("Leche entera " + s, todos.getString("[0].producto"));
        assertEquals(2, given().queryParam("estado", "pendiente").when().get("/api/usuarios/" + u + "/reportes").then()
                .extract().jsonPath().getList("$").size());
        assertEquals(0, given().queryParam("estado", "validado").when().get("/api/usuarios/" + u + "/reportes").then()
                .extract().jsonPath().getList("$").size());
        given().queryParam("estado", "inventado").when().get("/api/usuarios/" + u + "/reportes").then().statusCode(400);
        given().when().get("/api/usuarios/999999999/reportes").then().statusCode(404);
    }

    @Test
    void soloUnModeradorVeLaColaYValidaOPoRechaza() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        JsonPath r = registrar(s, u, "Éxito", 4500, true);
        long reporte = r.getLong("reporteId");

        given().queryParam("usuarioId", u).when().get("/api/precios/pendientes").then().statusCode(403)
                .body("error", containsString("moderador"));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u))
                .when().post("/api/precios/" + reporte + "/validar").then().statusCode(403);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "motivo", "x"))
                .when().post("/api/precios/" + reporte + "/rechazar").then().statusCode(403);
        given().when().get("/api/precios/pendientes").then().statusCode(400);

        long mod = moderador(s);
        assertEquals("moderador", given().when().get("/api/usuarios/" + mod).then().statusCode(200).extract().jsonPath().getString("rol"));
        JsonPath cola = given().queryParam("usuarioId", mod).when().get("/api/precios/pendientes").then().statusCode(200).extract().jsonPath();
        assertTrue(cola.getList("reporteId").contains((int) reporte));
        assertTrue(cola.getBoolean("find { it.reporteId == " + reporte + " }.tieneEvidencia"));
    }

    @Test
    void alValidarElPrecioPasaAserOficial() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long mod = moderador(s);
        JsonPath r = registrar(s, u, "Éxito", 4500, true);
        long id = r.getLong("productoId");
        JsonPath d1 = nuevoPrecio(id, u, "D1", "D1 Sede " + s, 3900, null);

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod))
                .when().post("/api/precios/" + r.getLong("reporteId") + "/validar").then().statusCode(200)
                .body("estado", equalTo("validado"));
        JsonPath comp = given().when().get("/api/productos/" + id + "/comparacion").then().extract().jsonPath();
        assertEquals(1, comp.getList("precios").size());                         // el de D1 sigue pendiente
        assertEquals(4500.0, comp.getDouble("precios[0].precioCop"), 0.001);
        JsonPath cat = given().queryParam("q", s).when().get("/api/productos").then().extract().jsonPath();
        assertEquals(4500.0, cat.getDouble("items[0].precioMin"), 0.001);
        assertEquals(1, cat.getInt("items[0].nPendientes"));

        // Validar el de D1: ahora es el más barato
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod))
                .when().post("/api/precios/" + d1.getLong("reporteId") + "/validar").then().statusCode(200);
        JsonPath comp2 = given().when().get("/api/productos/" + id + "/comparacion").then().extract().jsonPath();
        assertEquals("D1", comp2.getString("precios[0].almacen"));
        assertEquals(600.0, comp2.getDouble("resumen.ahorroMaximoCop"), 0.001);
        assertEquals("validado", given().when().get("/api/productos/" + id + "/historial").then().extract().jsonPath().getString("[0].estado"));
    }

    @Test
    void unPrecioRechazadoNoEsOficialPeroQuedaEnElHistorial() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long mod = moderador(s);
        JsonPath r = registrar(s, u, "Éxito", 4500, false);
        long id = r.getLong("productoId");

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod, "motivo", "  La foto no se ve  "))
                .when().post("/api/precios/" + r.getLong("reporteId") + "/rechazar").then().statusCode(200)
                .body("estado", equalTo("rechazado"));
        given().when().get("/api/productos/" + id + "/comparacion").then().body("precios.size()", equalTo(0));
        JsonPath h = given().when().get("/api/productos/" + id + "/historial").then().extract().jsonPath();
        assertEquals("rechazado", h.getString("[0].estado"));
        assertEquals("La foto no se ve", h.getString("[0].motivoRechazo"));
        assertEquals("rechazado", given().queryParam("estado", "rechazado").when().get("/api/usuarios/" + u + "/reportes")
                .then().extract().jsonPath().getString("[0].estado"));
    }

    @Test
    void unReporteSoloSePuedeProcesarUnaVez() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long mod = moderador(s);
        long reporte = registrar(s, u, "Éxito", 4500, false).getLong("reporteId");
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod)).when().post("/api/precios/" + reporte + "/validar").then().statusCode(200);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod)).when().post("/api/precios/" + reporte + "/validar").then().statusCode(409);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod, "motivo", "tarde")).when().post("/api/precios/" + reporte + "/rechazar").then().statusCode(409);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod)).when().post("/api/precios/999999999/validar").then().statusCode(404);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod, "motivo", "x".repeat(201))).when().post("/api/precios/999999999/rechazar").then().statusCode(400);
        // ya no está en la cola de moderación
        assertTrue(!given().queryParam("usuarioId", mod).when().get("/api/precios/pendientes").then().extract().jsonPath()
                .getList("reporteId").contains((int) reporte));
    }

    @Test
    void laListaDeMercadoSoloUsaPreciosValidados() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long mod = moderador(s);
        // Leche: Éxito 5000 (validado) y D1 1000 (pendiente)
        long leche = registrar(s, u, "Éxito " + s, 5000, false).getLong("productoId");
        long reporteExito = given().when().get("/api/productos/" + leche + "/historial").then().extract().jsonPath().getLong("[0].reporteId");
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod)).when().post("/api/precios/" + reporteExito + "/validar").then().statusCode(200);
        JsonPath d1 = nuevoPrecio(leche, u, "D1 " + s, "D1 Sede " + s, 1000, null);
        long lista = ListasTestApi.crearLista(u, "Mercado " + s);
        ListasTestApi.agregar(lista, u, leche, 3);

        JsonPath antes = given().queryParam("usuarioId", u).when().get("/api/listas/" + lista + "/valoracion").then().extract().jsonPath();
        assertEquals(List.of("Éxito " + s), antes.getList("supermercados.almacen"));          // D1 pendiente: no cuenta
        assertEquals(15000.0, antes.getDouble("supermercados[0].total"), 0.001);

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", mod)).when().post("/api/precios/" + d1.getLong("reporteId") + "/validar").then().statusCode(200);
        JsonPath despues = given().queryParam("usuarioId", u).when().get("/api/listas/" + lista + "/valoracion").then().extract().jsonPath();
        assertEquals(List.of("D1 " + s, "Éxito " + s), despues.getList("supermercados.almacen"));
        assertEquals(12000.0, despues.getDouble("resumen.ahorroCop"), 0.001);                 // 15000 - 3000
        assertEquals(80.0, despues.getDouble("resumen.ahorroPct"), 0.001);
    }
}
