package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Pruebas de integración de la API contra PostgreSQL (Dev Services/Docker, o una rama de Neon
 * indicada con -Dquarkus.datasource.jdbc.url=...). Usan sufijos únicos: no chocan con datos existentes.
 */
@QuarkusTest
class ProductoResourceTest {

    private static Map<String, Object> producto(String sufijo, long usuarioId, String almacen, String sede,
                                                String ciudad, double precio) {
        Map<String, Object> m = new HashMap<>();
        m.put("nombre", "Leche entera " + sufijo);
        m.put("marca", "Alquería");
        m.put("categoria", "Lácteos y huevos");
        m.put("presentacion", "Bolsa");
        m.put("cantidad", 1100);
        m.put("unidad", "ml");
        m.put("precioCop", precio);
        m.put("almacen", almacen);
        m.put("sede", sede);
        m.put("ciudad", ciudad);
        m.put("usuarioId", usuarioId);
        return m;
    }

    private static long crearUsuario(String sufijo) {
        return given().contentType(ContentType.JSON)
                .body(Map.of("nombre", "Tester " + sufijo, "email", "t" + sufijo + "@example.com"))
                .when().post("/api/usuarios").then().statusCode(200)
                .body("id", notNullValue()).extract().jsonPath().getLong("id");
    }

    @Test
    void saludConfirmaConexionConLaBaseDeDatos() {
        given().when().get("/api/salud").then().statusCode(200)
                .body("estado", equalTo("ok")).body("baseDeDatos", equalTo("conectada"));
    }

    @Test
    void flujoCompletoRegistroConsultaFiltrosComparacionEHistorial() {
        String s = UUID.randomUUID().toString().substring(0, 8);
        long usuario = crearUsuario(s);

        int id = given().contentType(ContentType.JSON).body(producto(s, usuario, "Éxito", "Éxito Chapinero " + s, "Bogotá", 4500))
                .when().post("/api/productos").then().statusCode(201)
                .body("productoNuevo", equalTo(true)).extract().jsonPath().getInt("productoId");

        // Segundo precio en otro almacén: el producto se reutiliza (200, no se duplica)
        given().contentType(ContentType.JSON).body(producto(s, usuario, "D1", "D1 Suba " + s, "Bogotá", 3900))
                .when().post("/api/productos").then().statusCode(200)
                .body("productoNuevo", equalTo(false)).body("productoId", equalTo(id));

        // Nuevo precio por el endpoint específico
        given().contentType(ContentType.JSON)
                .body(Map.of("almacen", "Ara", "sede", "Ara Kennedy " + s, "ciudad", "Medellín",
                        "precioCop", 4100, "usuarioId", usuario))
                .when().post("/api/productos/" + id + "/precios").then().statusCode(201);

        // Catálogo + filtros combinables
        given().queryParam("q", s).when().get("/api/productos").then().statusCode(200)
                .body("total", equalTo(1)).body("items[0].nSedes", equalTo(3))
                .body("items[0].precioMin", equalTo(3900.0f)).body("items[0].mejorAlmacen", equalTo("D1"));
        given().queryParam("q", s).queryParam("ciudad", "medellín").when().get("/api/productos").then()
                .body("items", hasSize(1)).body("items[0].nSedes", equalTo(1));
        given().queryParam("q", s).queryParam("precioMin", 4000).queryParam("precioMax", 4200)
                .when().get("/api/productos").then().body("items", hasSize(1)).body("items[0].precioMin", equalTo(4100.0f));
        given().queryParam("q", s).queryParam("precioMin", 9000).when().get("/api/productos").then()
                .body("items", hasSize(0));

        // Detalle
        given().when().get("/api/productos/" + id).then().statusCode(200)
                .body("nombre", equalTo("Leche entera " + s)).body("marca", equalTo("Alquería"));

        // Comparador
        given().queryParam("unidades", 10).when().get("/api/productos/" + id + "/comparacion").then().statusCode(200)
                .body("precios", hasSize(3))
                .body("precios[0].sede", equalTo("D1 Suba " + s)).body("precios[0].esMasBarato", equalTo(true))
                .body("precios[2].diferenciaCop", equalTo(600.0f))
                .body("resumen.ahorroMaximoCop", equalTo(600.0f))
                .body("resumen.ahorroTotalCop", equalTo(6000.0f))
                .body("resumen.masEconomico.almacen", equalTo("D1"));

        // Historial conserva los reportes
        given().when().get("/api/productos/" + id + "/historial").then().statusCode(200)
                .body("$", hasSize(3)).body("usuario", hasItem("Tester " + s));
    }

    @Test
    void validacionesDevuelven400ConMensaje() {
        String s = UUID.randomUUID().toString().substring(0, 8);
        long usuario = crearUsuario(s);
        given().contentType(ContentType.JSON).body(producto(s, usuario, "Éxito", "Sede " + s, "Bogotá", -5))
                .when().post("/api/productos").then().statusCode(400).body("error", containsString("precio"));
        Map<String, Object> futuro = producto(s, usuario, "Éxito", "Sede " + s, "Bogotá", 1000);
        futuro.put("fecha", "2999-01-01");
        given().contentType(ContentType.JSON).body(futuro)
                .when().post("/api/productos").then().statusCode(400).body("error", containsString("futura"));
        given().contentType(ContentType.JSON).body(Map.of("nombre", "X", "email", "no-es-correo"))
                .when().post("/api/usuarios").then().statusCode(400);
        given().queryParam("precioMin", 10).queryParam("precioMax", 5).when().get("/api/productos").then().statusCode(400);
        given().when().get("/api/productos/999999999").then().statusCode(404).body("error", notNullValue());
    }

    @Test
    void catalogosDisponibles() {
        given().when().get("/api/categorias").then().statusCode(200).body("size()", greaterThan(0));
        given().when().get("/api/establecimientos").then().statusCode(200).body("nombre", hasItem("Éxito"));
    }
}
