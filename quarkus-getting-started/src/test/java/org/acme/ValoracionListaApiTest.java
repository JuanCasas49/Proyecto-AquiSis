package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** HU-07: valor total estimado de la lista por supermercado y ahorro frente al más costoso. */
@QuarkusTest
class ValoracionListaApiTest {

    private static JsonPath valorar(long lista, long usuario, String... paramYValor) {
        var req = given().queryParam("usuarioId", usuario);
        for (int i = 0; i + 1 < paramYValor.length; i += 2) {
            req = req.queryParam(paramYValor[i], paramYValor[i + 1]);
        }
        return req.when().get("/api/listas/" + lista + "/valoracion").then().statusCode(200).extract().jsonPath();
    }

    @Test
    void calculaElTotalSumandoElPrecioVigenteDeCadaProductoPorSupermercado() {
        var e = ListasTestApi.Escenario.crear();
        JsonPath v = valorar(e.lista(), e.usuario());
        assertEquals(3, v.getList("supermercados").size());
        assertEquals(3, v.getInt("nProductos"));
        assertEquals(4, v.getInt("nUnidades"));
        // De menor a mayor total entre los supermercados completos; el incompleto al final
        assertEquals(List.of(e.ara(), e.exito(), e.d1()), v.getList("supermercados.almacen"));
        assertEquals(22700.0, v.getDouble("supermercados[0].total"), 0.001);   // 2x4100 + 3500 + 11000
        assertEquals(25600.0, v.getDouble("supermercados[1].total"), 0.001);   // 2x5000 + 3600 + 12000
        assertEquals(11000.0, v.getDouble("supermercados[2].total"), 0.001);   // parcial: falta el aceite
    }

    @Test
    void detallaCadaLineaConPrecioUnitarioYSubtotal() {
        var e = ListasTestApi.Escenario.crear();
        JsonPath v = valorar(e.lista(), e.usuario());
        assertEquals(3, v.getList("supermercados[1].lineas").size());
        assertEquals(2, v.getInt("supermercados[1].lineas.find { it.producto.startsWith('Leche') }.cantidad"));
        assertEquals(5000.0, v.getDouble("supermercados[1].lineas.find { it.producto.startsWith('Leche') }.precioUnitario"), 0.001);
        assertEquals(10000.0, v.getDouble("supermercados[1].lineas.find { it.producto.startsWith('Leche') }.subtotal"), 0.001);
    }

    @Test
    void muestraElAhorroEnPesosYPorcentajeRespectoAlMasCostoso() {
        var e = ListasTestApi.Escenario.crear();
        JsonPath v = valorar(e.lista(), e.usuario());
        assertEquals(2, v.getInt("resumen.nComparables"));
        assertEquals(e.ara(), v.getString("resumen.masEconomico"));
        assertEquals(e.exito(), v.getString("resumen.masCostoso"));
        assertEquals(22700.0, v.getDouble("resumen.totalMasEconomico"), 0.001);
        assertEquals(25600.0, v.getDouble("resumen.totalMasCostoso"), 0.001);
        assertEquals(2900.0, v.getDouble("resumen.ahorroCop"), 0.001);
        assertEquals(11.3, v.getDouble("resumen.ahorroPct"), 0.001);
        assertTrue(v.getBoolean("supermercados[0].esMasEconomico"));
        assertFalse(v.getBoolean("supermercados[1].esMasEconomico"));
        assertEquals(2900.0, v.getDouble("supermercados[1].diferenciaCop"), 0.001);
        assertEquals(12.8, v.getDouble("supermercados[1].diferenciaPct"), 0.001);
    }

    @Test
    void unSupermercadoIncompletoMuestraLoQueLeFaltaYNoEntraEnLaComparacion() {
        var e = ListasTestApi.Escenario.crear();
        JsonPath v = valorar(e.lista(), e.usuario());
        assertFalse(v.getBoolean("supermercados[2].completo"));
        assertEquals(2, v.getInt("supermercados[2].productosConPrecio"));
        assertEquals(List.of("Aceite V " + e.s()), v.getList("supermercados[2].productosSinPrecio"));
        assertNull(v.get("supermercados[2].diferenciaCop"));
        assertTrue(v.getBoolean("supermercados[0].completo"));
    }

    @Test
    void cambiarLaCantidadActualizaLosTotalesYElAhorro() {
        var e = ListasTestApi.Escenario.crear();
        given().contentType(ContentType.JSON).body(Map.of("usuarioId", e.usuario(), "cantidad", 1))
                .when().put("/api/listas/" + e.lista() + "/items/" + e.leche()).then().statusCode(200);
        JsonPath v = valorar(e.lista(), e.usuario());
        assertEquals(18600.0, v.getDouble("supermercados[0].total"), 0.001);   // 4100 + 3500 + 11000
        assertEquals(20600.0, v.getDouble("supermercados[1].total"), 0.001);   // 5000 + 3600 + 12000
        assertEquals(2000.0, v.getDouble("resumen.ahorroCop"), 0.001);
        assertEquals(9.7, v.getDouble("resumen.ahorroPct"), 0.001);
    }

    @Test
    void usaElPrecioMasRecienteDeCadaSupermercado() {
        var e = ListasTestApi.Escenario.crear();
        // Ara baja la leche: el total de Ara cambia y el ahorro aumenta
        ListasTestApi.precio(e.leche(), e.usuario(), e.ara(), e.ara() + " Centro", "Bogotá", 3000, null);
        JsonPath v = valorar(e.lista(), e.usuario());
        assertEquals(20500.0, v.getDouble("supermercados[0].total"), 0.001);   // 2x3000 + 3500 + 11000
        assertEquals(5100.0, v.getDouble("resumen.ahorroCop"), 0.001);
    }

    @Test
    void avisaCuandoUnPrecioUsadoPuedeEstarDesactualizado() {
        var e = ListasTestApi.Escenario.crear();
        JsonPath v = valorar(e.lista(), e.usuario());
        assertTrue(v.getBoolean("resumen.hayPreciosDesactualizados"));
        assertTrue(v.getBoolean("supermercados[0].hayDesactualizados"));                        // Ara: aceite de 45 días
        assertFalse(v.getBoolean("supermercados[1].hayDesactualizados"));
        assertTrue(v.getBoolean("supermercados[0].lineas.find { it.producto.startsWith('Aceite') }.desactualizado"));
        assertEquals(30, v.getInt("diasVigencia"));
    }

    @Test
    void permiteValorarSoloUnaCiudad() {
        var e = ListasTestApi.Escenario.crear();
        ListasTestApi.precio(e.leche(), e.usuario(), e.exito(), e.exito() + " Sur", "Cali", 1000, null);
        JsonPath cali = valorar(e.lista(), e.usuario(), "ciudad", "Cali");
        assertEquals(1, cali.getList("supermercados").size());
        assertEquals(e.exito(), cali.getString("supermercados[0].almacen"));
        assertEquals(2000.0, cali.getDouble("supermercados[0].total"), 0.001);
        assertFalse(cali.getBoolean("supermercados[0].completo"));
        assertEquals(0, cali.getInt("resumen.nComparables"));
        assertEquals(0.0, cali.getDouble("resumen.ahorroCop"), 0.001);
        assertEquals("Cali", cali.getString("ciudad"));
    }

    @Test
    void unaListaVaciaNoTieneValorNiAhorro() {
        String s = TestApi.sufijo();
        long u = TestApi.crearUsuario(s);
        long lista = ListasTestApi.crearLista(u, "Vacía " + s);
        JsonPath v = valorar(lista, u);
        assertTrue(v.getList("supermercados").isEmpty());
        assertEquals(0, v.getInt("nProductos"));
        assertEquals(0, v.getInt("resumen.nComparables"));
    }

    @Test
    void exigeUsuarioYRespetaLaPropiedadDeLaLista() {
        var e = ListasTestApi.Escenario.crear();
        given().when().get("/api/listas/" + e.lista() + "/valoracion").then().statusCode(400);
        long otro = TestApi.crearUsuario(TestApi.sufijo());
        given().queryParam("usuarioId", otro).when().get("/api/listas/" + e.lista() + "/valoracion").then().statusCode(404);
    }
}
