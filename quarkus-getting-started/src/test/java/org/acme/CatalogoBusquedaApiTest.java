package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Funcionalidad: catálogo, búsqueda y filtros combinables. */
@QuarkusTest
class CatalogoBusquedaApiTest {

    private static List<Integer> ids(String s, String... paramYValor) {
        var req = given().queryParam("q", s);
        for (int i = 0; i + 1 < paramYValor.length; i += 2) {
            req = req.queryParam(paramYValor[i], paramYValor[i + 1]);
        }
        return req.when().get("/api/productos").then().statusCode(200).extract().jsonPath().getList("items.id");
    }

    @Test
    void elCatalogoMuestraCaracteristicasPreciosYEstablecimientos() {
        var f = TestApi.Fixture.crear();
        var jp = given().queryParam("q", f.s()).queryParam("orden", "precio_asc")
                .when().get("/api/productos").then().statusCode(200).extract().jsonPath();
        assertEquals(2, jp.getInt("total"));
        // arroz (mín 3200) primero
        assertEquals("Arroz blanco " + f.s(), jp.getString("items[0].nombre"));
        assertEquals("Diana", jp.getString("items[0].marca"));
        assertEquals("Granos y cereales", jp.getString("items[0].categoria"));
        assertEquals("Bolsa", jp.getString("items[0].presentacion"));
        assertEquals(3200.0, jp.getDouble("items[0].precioMin"), 0.001);
        assertEquals(3600.0, jp.getDouble("items[0].precioMax"), 0.001);
        assertEquals(2, jp.getInt("items[0].nSedes"));
        assertEquals("Jumbo", jp.getString("items[0].mejorAlmacen"));
        // leche: 3900 / 5000 en 3 sedes, más barato en D1
        assertEquals(3900.0, jp.getDouble("items[1].precioMin"), 0.001);
        assertEquals(5000.0, jp.getDouble("items[1].precioMax"), 0.001);
        assertEquals(3, jp.getInt("items[1].nSedes"));
        assertEquals("D1", jp.getString("items[1].mejorAlmacen"));
    }

    @Test
    void buscaPorNombreMarcaIgnorandoTildesYMayusculas() {
        var f = TestApi.Fixture.crear();
        assertEquals(2, ids(f.s()).size());
        assertEquals(List.of((int) f.leche()), ids("LECHE ENTERA " + f.s()));
        assertEquals(List.of((int) f.arroz()), ids("arroz blanco " + f.s()));

        java.util.Map<String, Object> jalapeno = TestApi.leche(f.s(), f.usuario(), "Éxito", "Éxito Norte " + f.s(), "Bogotá", 9000);
        jalapeno.put("nombre", "Jalapeño picante " + f.s());
        jalapeno.put("marca", "Tabasco");
        jalapeno.put("categoria", "Despensa");
        jalapeno.put("presentacion", "Frasco");
        jalapeno.put("cantidad", 150);
        long id = TestApi.registrar(jalapeno);
        assertEquals(List.of((int) id), ids("JALAPENO PICANTE " + f.s()));
    }

    @Test
    void sinCoincidenciasDevuelveListaVacia() {
        given().queryParam("q", "zzzz-no-existe-" + TestApi.sufijo()).when().get("/api/productos").then()
                .statusCode(200).body("total", equalTo(0)).body("items", hasSize(0));
    }

    @Test
    void elTextoConPorcentajeNoActuaComoComodin() {
        given().queryParam("q", "%").when().get("/api/productos").then().statusCode(200).body("total", equalTo(0));
    }

    @Test
    void filtraPorCategoriaYMarca() {
        var f = TestApi.Fixture.crear();
        long granos = TestApi.idPorNombre("/api/categorias", "Granos y cereales");
        long lacteos = TestApi.idPorNombre("/api/categorias", "Lácteos y huevos");
        long diana = TestApi.idPorNombre("/api/marcas", "Diana");
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "categoriaId", "" + granos));
        assertEquals(List.of((int) f.leche()), ids(f.s(), "categoriaId", "" + lacteos));
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "marcaId", "" + diana));
    }

    @Test
    void filtraPorAlmacenYCiudadSobreLosPreciosVigentes() {
        var f = TestApi.Fixture.crear();
        long d1 = TestApi.idPorNombre("/api/establecimientos", "D1");
        long jumbo = TestApi.idPorNombre("/api/establecimientos", "Jumbo");
        assertEquals(2, ids(f.s(), "establecimientoId", "" + d1).size());
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "establecimientoId", "" + jumbo));
        assertEquals(List.of((int) f.leche()), ids(f.s(), "ciudad", "medellín"));   // sin importar tildes/mayúsculas del valor guardado
        assertEquals(2, ids(f.s(), "ciudad", "Bogotá").size());
        assertTrue(ids(f.s(), "ciudad", "Cali").isEmpty());
    }

    @Test
    void filtraPorRangoDePrecios() {
        var f = TestApi.Fixture.crear();
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "precioMin", "3500", "precioMax", "3700"));
        assertEquals(List.of((int) f.leche()), ids(f.s(), "precioMin", "4000", "precioMax", "4200"));
        assertEquals(2, ids(f.s(), "precioMax", "5000").size());
        assertTrue(ids(f.s(), "precioMin", "9000").isEmpty());
    }

    @Test
    void elPrecioHistoricoNoCuentaComoVigente() {
        var f = TestApi.Fixture.crear();
        // La leche en D1 Suba pasa de 3900 a 4500: 3900 ya no es un precio vigente
        TestApi.agregarPrecio(f.leche(), f.usuario(), "D1", "D1 Suba " + f.s(), "Bogotá", 4500, null);
        assertTrue(ids(f.s(), "precioMin", "3800", "precioMax", "3950").isEmpty());
        assertEquals(List.of((int) f.leche()), ids(f.s(), "precioMin", "4400", "precioMax", "4600"));
    }

    @Test
    void combinaVariosFiltros() {
        var f = TestApi.Fixture.crear();
        long d1 = TestApi.idPorNombre("/api/establecimientos", "D1");
        long granos = TestApi.idPorNombre("/api/categorias", "Granos y cereales");
        // D1 + precio máximo 3700: solo el arroz (3600); la leche cuesta 3900 en D1
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "establecimientoId", "" + d1, "precioMax", "3700"));
        // categoría + ciudad + precio
        assertEquals(List.of((int) f.arroz()), ids(f.s(), "categoriaId", "" + granos, "ciudad", "Bogotá", "precioMax", "3500"));
        // combinación imposible
        assertTrue(ids(f.s(), "categoriaId", "" + granos, "ciudad", "Medellín").isEmpty());
    }

    @Test
    void ordenaPorPrecioNombreYReciente() {
        var f = TestApi.Fixture.crear();
        assertEquals(List.of((int) f.arroz(), (int) f.leche()), ids(f.s(), "orden", "precio_asc"));
        assertEquals(List.of((int) f.leche(), (int) f.arroz()), ids(f.s(), "orden", "precio_desc"));
        assertEquals(List.of((int) f.arroz(), (int) f.leche()), ids(f.s(), "orden", "nombre"));   // Arroz < Leche
        assertEquals(2, ids(f.s(), "orden", "reciente").size());
    }

    @Test
    void paginaLosResultados() {
        var f = TestApi.Fixture.crear();
        var p1 = given().queryParam("q", f.s()).queryParam("tamano", 1).queryParam("pagina", 1).queryParam("orden", "nombre")
                .when().get("/api/productos").then().statusCode(200).extract().jsonPath();
        assertEquals(2, p1.getInt("total"));
        assertEquals(1, p1.getList("items").size());
        var p2 = given().queryParam("q", f.s()).queryParam("tamano", 1).queryParam("pagina", 2).queryParam("orden", "nombre")
                .when().get("/api/productos").then().statusCode(200).extract().jsonPath();
        assertEquals(1, p2.getList("items").size());
        assertEquals(false, p1.getInt("items[0].id") == p2.getInt("items[0].id"));
        given().queryParam("q", f.s()).queryParam("tamano", 1).queryParam("pagina", 3)
                .when().get("/api/productos").then().body("items", hasSize(0));
    }

    @Test
    void rechazaParametrosInvalidos() {
        given().queryParam("orden", "inventado").when().get("/api/productos").then().statusCode(400).body("error", containsString("Orden"));
        given().queryParam("precioMin", 10).queryParam("precioMax", 5).when().get("/api/productos").then().statusCode(400);
        given().queryParam("tamano", 0).when().get("/api/productos").then().statusCode(400);
        given().queryParam("tamano", 101).when().get("/api/productos").then().statusCode(400);
        given().queryParam("pagina", 0).when().get("/api/productos").then().statusCode(400);
        given().queryParam("q", "x".repeat(101)).when().get("/api/productos").then().statusCode(400);
    }

    @Test
    void detalleDelProducto() {
        var f = TestApi.Fixture.crear();
        given().when().get("/api/productos/" + f.leche()).then().statusCode(200)
                .body("nombre", equalTo("Leche entera " + f.s())).body("marca", equalTo("Alquería"))
                .body("categoria", equalTo("Lácteos y huevos")).body("presentacion", equalTo("Bolsa"))
                .body("unidad", equalTo("ml")).body("creadoPor", equalTo("Tester " + f.s()));
        given().when().get("/api/productos/999999999").then().statusCode(404).body("error", containsString("no encontrado"));
    }
}
