package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasItems;
import static org.hamcrest.Matchers.notNullValue;

/** Funcionalidad: listas de apoyo (categorías, marcas, almacenes, sedes, ciudades) y estado de la conexión. */
@QuarkusTest
class CatalogosApiTest {

    @Test
    void saludConfirmaLaConexionConLaBaseDeDatos() {
        given().when().get("/api/salud").then().statusCode(200)
                .body("estado", equalTo("ok")).body("baseDeDatos", equalTo("conectada"))
                .body("productos", notNullValue()).body("reportes", notNullValue());
    }

    @Test
    void categoriasYAlmacenesIncluyenLosDatosBase() {
        given().when().get("/api/categorias").then().statusCode(200).body("size()", greaterThan(12))
                .body("nombre", hasItems("Lácteos y huevos", "Granos y cereales", "Bebidas"));
        given().when().get("/api/establecimientos").then().statusCode(200)
                .body("nombre", hasItems("Éxito", "D1", "Ara", "Jumbo"));
    }

    @Test
    void registrarUnProductoCreaMarcaSedeYCiudadParaLasListas() {
        var f = TestApi.Fixture.crear();
        given().when().get("/api/marcas").then().body("nombre", hasItems("Alquería", "Diana"));
        given().when().get("/api/ciudades").then().body("$", hasItems("Bogotá", "Medellín"));
        given().queryParam("ciudad", "Medellín").when().get("/api/sedes").then().statusCode(200)
                .body("nombre", hasItem("Ara Kennedy " + f.s()));
        long d1 = TestApi.idPorNombre("/api/establecimientos", "D1");
        given().queryParam("establecimientoId", d1).queryParam("ciudad", "bogotá").when().get("/api/sedes").then()
                .body("nombre", hasItem("D1 Suba " + f.s())).body("almacen", hasItem("D1"));
    }

    @Test
    void listasSinDuplicados() {
        var f = TestApi.Fixture.crear();
        // La misma sede "D1 Suba" se usó para dos productos y debe existir una sola vez
        var sedes = given().queryParam("ciudad", "Bogotá").when().get("/api/sedes").then().extract().jsonPath()
                .getList("findAll { it.nombre == 'D1 Suba " + f.s() + "' }");
        org.junit.jupiter.api.Assertions.assertEquals(1, sedes.size());
    }
}
