package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** HU-06: gestión de listas de mercado (crear varias, agregar, modificar cantidad, eliminar). */
@QuarkusTest
class ListasApiTest {

    private static long producto(String s, long usuario, String nombre) {
        return ListasTestApi.producto(nombre + " " + s, "Marca " + s, "Despensa", usuario, "Éxito", "Éxito Sede " + s, "Bogotá", 4000);
    }

    private static JsonPath detalle(long lista, long usuario) {
        return given().queryParam("usuarioId", usuario).when().get("/api/listas/" + lista).then().statusCode(200).extract().jsonPath();
    }

    @Test
    void permiteCrearMultiplesListasConNombrePropio() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long semana = given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "  Compra   semanal " + s))
                .when().post("/api/listas").then().statusCode(201)
                .body("nombre", equalTo("Compra semanal " + s)).body("nProductos", equalTo(0)).extract().jsonPath().getLong("id");
        long fiesta = ListasTestApi.crearLista(u, "Fiesta " + s);
        assertTrue(semana != fiesta);

        JsonPath listas = given().queryParam("usuarioId", u).when().get("/api/listas").then().statusCode(200).extract().jsonPath();
        assertEquals(2, listas.getList("$").size());
        assertEquals(List.of("Fiesta " + s, "Compra semanal " + s), listas.getList("nombre"));   // la más reciente primero
    }

    @Test
    void noPermiteNombresRepetidosPeroOtroUsuarioPuedeUsarElMismo() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long otro = TestApi.crearUsuario(s + "b");
        ListasTestApi.crearLista(u, "Fiesta " + s);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "FIESTA " + s))
                .when().post("/api/listas").then().statusCode(409).body("error", containsString("Ya tiene una lista"));
        ListasTestApi.crearLista(otro, "Fiesta " + s);
    }

    @Test
    void validaElNombreYElUsuario() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "   "))
                .when().post("/api/listas").then().statusCode(400).body("error", containsString("nombre"));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "x".repeat(81)))
                .when().post("/api/listas").then().statusCode(400);
        given().contentType(ContentType.JSON).body(Map.of("nombre", "Sin usuario"))
                .when().post("/api/listas").then().statusCode(400).body("error", containsString("identificarse"));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", 999999999L, "nombre", "Fantasma"))
                .when().post("/api/listas").then().statusCode(404);
        given().when().get("/api/listas").then().statusCode(400);
    }

    @Test
    void agregaProductosYSumaLaCantidadSiYaEstaban() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long leche = producto(s, u, "Leche");
        long arroz = producto(s, u, "Arroz");
        long lista = ListasTestApi.crearLista(u, "Mercado " + s);

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "productoId", leche, "cantidad", 2))
                .when().post("/api/listas/" + lista + "/items").then().statusCode(201)
                .body("cantidad", equalTo(2)).body("nombre", equalTo("Leche " + s)).body("marca", equalTo("Marca " + s));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "productoId", leche, "cantidad", 3))
                .when().post("/api/listas/" + lista + "/items").then().statusCode(201).body("cantidad", equalTo(5));
        ListasTestApi.agregar(lista, u, arroz, 1);

        JsonPath d = detalle(lista, u);
        assertEquals(2, d.getInt("nProductos"));
        assertEquals(6, d.getInt("nUnidades"));
        assertEquals(List.of("Arroz " + s, "Leche " + s), d.getList("items.nombre"));
    }

    @Test
    void modificaLaCantidadDeCadaProducto() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long leche = producto(s, u, "Leche");
        long lista = ListasTestApi.crearLista(u, "Mercado " + s);
        ListasTestApi.agregar(lista, u, leche, 2);

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "cantidad", 7))
                .when().put("/api/listas/" + lista + "/items/" + leche).then().statusCode(200).body("cantidad", equalTo(7));
        assertEquals(7, detalle(lista, u).getInt("items[0].cantidad"));
        assertEquals(7, given().queryParam("usuarioId", u).when().get("/api/listas").then().extract().jsonPath().getInt("[0].nUnidades"));
    }

    @Test
    void rechazaCantidadesFueraDeRangoYProductosAjenosALaLista() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long leche = producto(s, u, "Leche");
        long arroz = producto(s, u, "Arroz");
        long lista = ListasTestApi.crearLista(u, "Mercado " + s);
        ListasTestApi.agregar(lista, u, leche, 2);

        for (int cantidad : new int[]{0, -1, 1000}) {
            given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "cantidad", cantidad))
                    .when().put("/api/listas/" + lista + "/items/" + leche).then().statusCode(400)
                    .body("error", containsString("entre 1 y 999"));
            given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "productoId", leche, "cantidad", cantidad))
                    .when().post("/api/listas/" + lista + "/items").then().statusCode(400);
        }
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "cantidad", 3))
                .when().put("/api/listas/" + lista + "/items/" + arroz).then().statusCode(404)
                .body("error", containsString("no está en la lista"));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "productoId", 999999999L, "cantidad", 1))
                .when().post("/api/listas/" + lista + "/items").then().statusCode(404);
        assertEquals(2, detalle(lista, u).getInt("items[0].cantidad"));   // nada cambió
    }

    @Test
    void eliminaProductosDeLaLista() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long leche = producto(s, u, "Leche");
        long arroz = producto(s, u, "Arroz");
        long lista = ListasTestApi.crearLista(u, "Mercado " + s);
        ListasTestApi.agregar(lista, u, leche, 1);
        ListasTestApi.agregar(lista, u, arroz, 1);

        given().queryParam("usuarioId", u).when().delete("/api/listas/" + lista + "/items/" + leche).then().statusCode(204);
        assertEquals(List.of("Arroz " + s), detalle(lista, u).getList("items.nombre"));
        given().queryParam("usuarioId", u).when().delete("/api/listas/" + lista + "/items/" + leche).then().statusCode(404);
    }

    @Test
    void renombraYEliminaListas() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long a = ListasTestApi.crearLista(u, "Una " + s);
        ListasTestApi.crearLista(u, "Otra " + s);
        long leche = producto(s, u, "Leche");
        ListasTestApi.agregar(a, u, leche, 1);

        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "Mercado quincenal " + s))
                .when().put("/api/listas/" + a).then().statusCode(200).body("nombre", equalTo("Mercado quincenal " + s));
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", u, "nombre", "OTRA " + s))
                .when().put("/api/listas/" + a).then().statusCode(409);

        given().queryParam("usuarioId", u).when().delete("/api/listas/" + a).then().statusCode(204);
        given().queryParam("usuarioId", u).when().get("/api/listas/" + a).then().statusCode(404);
        assertEquals(1, given().queryParam("usuarioId", u).when().get("/api/listas").then().extract().jsonPath().getList("$").size());
    }

    @Test
    void unaListaAjenaNoSePuedeVerNiModificar() {
        String s = TestApi.sufijo();
        long dueno = TestApi.crearUsuario(s);
        long intruso = TestApi.crearUsuario(s + "x");
        long leche = producto(s, dueno, "Leche");
        long lista = ListasTestApi.crearLista(dueno, "Privada " + s);
        ListasTestApi.agregar(lista, dueno, leche, 2);

        given().queryParam("usuarioId", intruso).when().get("/api/listas/" + lista).then().statusCode(404);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", intruso, "productoId", leche, "cantidad", 1))
                .when().post("/api/listas/" + lista + "/items").then().statusCode(404);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", intruso, "cantidad", 9))
                .when().put("/api/listas/" + lista + "/items/" + leche).then().statusCode(404);
        given().queryParam("usuarioId", intruso).when().delete("/api/listas/" + lista + "/items/" + leche).then().statusCode(404);
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", intruso, "nombre", "Mía"))
                .when().put("/api/listas/" + lista).then().statusCode(404);
        given().queryParam("usuarioId", intruso).when().delete("/api/listas/" + lista).then().statusCode(404);
        given().queryParam("usuarioId", intruso).when().get("/api/listas/" + lista + "/valoracion").then().statusCode(404);
        assertTrue(given().queryParam("usuarioId", intruso).when().get("/api/listas").then().extract().jsonPath().getList("$").isEmpty());
        assertEquals(2, detalle(lista, dueno).getInt("items[0].cantidad"));   // intacta
    }

    @Test
    void consultarUnaListaInexistenteDevuelve404() {
        long u = TestApi.crearUsuario(TestApi.sufijo());
        given().queryParam("usuarioId", u).when().get("/api/listas/999999999").then().statusCode(404);
        given().when().get("/api/listas/999999999").then().statusCode(400);
    }
}
