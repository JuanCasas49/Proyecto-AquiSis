package org.acme;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Funcionalidades: comparador de precios (más barato, diferencias, ahorros) e historial con advertencias. */
@QuarkusTest
class ComparadorHistorialApiTest {

    private static JsonPath comparar(long id, String... paramYValor) {
        var req = given();
        for (int i = 0; i + 1 < paramYValor.length; i += 2) {
            req = req.queryParam(paramYValor[i], paramYValor[i + 1]);
        }
        return req.when().get("/api/productos/" + id + "/comparacion").then().statusCode(200).extract().jsonPath();
    }

    private static JsonPath historial(long id, String... paramYValor) {
        var req = given();
        for (int i = 0; i + 1 < paramYValor.length; i += 2) {
            req = req.queryParam(paramYValor[i], paramYValor[i + 1]);
        }
        return req.when().get("/api/productos/" + id + "/historial").then().statusCode(200).extract().jsonPath();
    }

    private static List<Double> numeros(JsonPath jp, String ruta) {
        List<Number> valores = jp.getList(ruta);
        return valores.stream().map(Number::doubleValue).toList();
    }

    // ----------------------------------------------------------- comparador --

    @Test
    void ordenaLosPreciosDeMenorAMayorEIdentificaElMasEconomico() {
        var f = TestApi.Fixture.crear();
        JsonPath c = comparar(f.leche());
        assertEquals(3, c.getList("precios").size());
        assertEquals(List.of(3900.0, 4100.0, 5000.0), numeros(c, "precios.precioCop"));
        assertEquals("D1", c.getString("precios[0].almacen"));
        assertEquals("Ara", c.getString("precios[1].almacen"));
        assertEquals("Éxito", c.getString("precios[2].almacen"));
        assertTrue(c.getBoolean("precios[0].esMasBarato"));
        assertFalse(c.getBoolean("precios[1].esMasBarato"));
        assertFalse(c.getBoolean("precios[2].esMasBarato"));
        assertEquals("Leche entera " + f.s(), c.getString("producto.nombre"));
        assertEquals(30, c.getInt("diasVigencia"));
    }

    @Test
    void calculaDiferenciasContraElMasBarato() {
        var f = TestApi.Fixture.crear();
        JsonPath c = comparar(f.leche());
        assertEquals(0.0, c.getDouble("precios[0].diferenciaCop"), 0.001);
        assertEquals(200.0, c.getDouble("precios[1].diferenciaCop"), 0.001);
        assertEquals(5.1, c.getDouble("precios[1].diferenciaPct"), 0.001);
        assertEquals(1100.0, c.getDouble("precios[2].diferenciaCop"), 0.001);
        assertEquals(28.2, c.getDouble("precios[2].diferenciaPct"), 0.001);
    }

    @Test
    void calculaAhorrosPotenciales() {
        var f = TestApi.Fixture.crear();
        JsonPath c = comparar(f.leche(), "unidades", "10");
        assertEquals(3, c.getInt("resumen.nSedes"));
        assertEquals(3900.0, c.getDouble("resumen.precioMinimo"), 0.001);
        assertEquals(5000.0, c.getDouble("resumen.precioMaximo"), 0.001);
        assertEquals(4333.33, c.getDouble("resumen.precioPromedio"), 0.001);
        assertEquals("D1", c.getString("resumen.masEconomico.almacen"));
        assertEquals("Éxito", c.getString("resumen.masCaro.almacen"));
        assertEquals(1100.0, c.getDouble("resumen.ahorroMaximoCop"), 0.001);
        assertEquals(22.0, c.getDouble("resumen.ahorroMaximoPct"), 0.001);
        assertEquals(10, c.getInt("resumen.unidades"));
        assertEquals(11000.0, c.getDouble("resumen.ahorroTotalCop"), 0.001);
        assertEquals(433.33, c.getDouble("resumen.ahorroVsPromedioCop"), 0.001);
        assertFalse(c.getBoolean("resumen.hayPreciosDesactualizados"));
    }

    @Test
    void conUnaSolaSedeNoHayAhorro() {
        var f = TestApi.Fixture.crear();
        JsonPath c = comparar(f.leche(), "ciudad", "Medellín");
        assertEquals(1, c.getList("precios").size());
        assertEquals(0.0, c.getDouble("resumen.ahorroMaximoCop"), 0.001);
        assertTrue(c.getBoolean("precios[0].esMasBarato"));
    }

    @Test
    void filtraElComparadorPorCiudadYAlmacen() {
        var f = TestApi.Fixture.crear();
        JsonPath bogota = comparar(f.leche(), "ciudad", "bogotá");
        assertEquals(List.of("D1", "Éxito"), bogota.getList("precios.almacen"));
        assertEquals(1100.0, bogota.getDouble("resumen.ahorroMaximoCop"), 0.001);

        long exito = TestApi.idPorNombre("/api/establecimientos", "Éxito");
        JsonPath soloExito = comparar(f.leche(), "establecimientoId", "" + exito);
        assertEquals(List.of("Éxito"), soloExito.getList("precios.almacen"));

        JsonPath nada = comparar(f.leche(), "ciudad", "Cali");
        assertTrue(nada.getList("precios").isEmpty());
        assertNull(nada.get("resumen"));
    }

    @Test
    void elComparadorUsaSoloElUltimoPrecioDeCadaSede() {
        var f = TestApi.Fixture.crear();
        TestApi.agregarPrecio(f.leche(), f.usuario(), "D1", "D1 Suba " + f.s(), "Bogotá", 4500, null);
        JsonPath c = comparar(f.leche());
        assertEquals(3, c.getList("precios").size());
        assertEquals(List.of(4100.0, 4500.0, 5000.0), numeros(c, "precios.precioCop"));
        assertEquals("Ara", c.getString("resumen.masEconomico.almacen"));
    }

    @Test
    void avisaCuandoUnPrecioPuedeEstarDesactualizado() {
        var f = TestApi.Fixture.crear();
        TestApi.agregarPrecio(f.leche(), f.usuario(), "Olímpica", "Olímpica Centro " + f.s(), "Cali", 1000,
                LocalDate.now().minusDays(45));
        JsonPath c = comparar(f.leche());
        assertEquals("Olímpica", c.getString("precios[0].almacen"));
        assertTrue(c.getBoolean("precios[0].desactualizado"));
        assertTrue(c.getInt("precios[0].dias") >= 44);
        assertFalse(c.getBoolean("precios[1].desactualizado"));
        assertTrue(c.getBoolean("resumen.masEconomicoDesactualizado"));
        assertTrue(c.getBoolean("resumen.hayPreciosDesactualizados"));
    }

    @Test
    void rechazaParametrosInvalidosYProductosInexistentes() {
        var f = TestApi.Fixture.crear();
        given().queryParam("unidades", 0).when().get("/api/productos/" + f.leche() + "/comparacion").then().statusCode(400);
        given().queryParam("unidades", 1001).when().get("/api/productos/" + f.leche() + "/comparacion").then().statusCode(400);
        given().when().get("/api/productos/999999999/comparacion").then().statusCode(404)
                .body("error", containsString("no encontrado"));
    }

    // ------------------------------------------------------------ historial --

    @Test
    void conservaTodosLosReportesConFechaYUsuario() {
        var f = TestApi.Fixture.crear();
        JsonPath h = historial(f.leche());
        assertEquals(3, h.getList("$").size());
        assertTrue(h.getList("usuario").stream().allMatch(u -> u.equals("Tester " + f.s())));
        assertEquals(LocalDate.now().toString().substring(0, 4), h.getString("[0].fecha").substring(0, 4));
        assertFalse(h.getBoolean("[0].desactualizado"));
    }

    @Test
    void muestraLaVariacionDePrecioDeUnaMismaSede() {
        var f = TestApi.Fixture.crear();
        TestApi.agregarPrecio(f.leche(), f.usuario(), "D1", "D1 Suba " + f.s(), "Bogotá", 4500, null);
        JsonPath h = historial(f.leche());
        assertEquals(4, h.getList("$").size());
        // El reporte más reciente es el de D1 a 4500, con +600 frente al anterior de la misma sede
        assertEquals(4500.0, h.getDouble("[0].precioCop"), 0.001);
        assertEquals(600.0, h.getDouble("[0].variacionCop"), 0.001);
        List<Object> variaciones = h.getList("variacionCop");
        assertEquals(1, variaciones.stream().filter(v -> v != null).count());   // las demás son primeros reportes
    }

    @Test
    void ordenaDelMasRecienteAlMasAntiguoYMarcaLosViejos() {
        var f = TestApi.Fixture.crear();
        TestApi.agregarPrecio(f.leche(), f.usuario(), "Olímpica", "Olímpica Centro " + f.s(), "Cali", 4000,
                LocalDate.now().minusDays(60));
        JsonPath h = historial(f.leche());
        assertEquals(4, h.getList("$").size());
        int ultimo = h.getList("$").size() - 1;
        assertEquals("Olímpica", h.getString("[" + ultimo + "].almacen"));
        assertTrue(h.getBoolean("[" + ultimo + "].desactualizado"));
        assertTrue(h.getInt("[" + ultimo + "].dias") >= 59);
    }

    @Test
    void filtraElHistorialPorSedeYLimitaLaCantidad() {
        var f = TestApi.Fixture.crear();
        TestApi.agregarPrecio(f.leche(), f.usuario(), "D1", "D1 Suba " + f.s(), "Bogotá", 4500, null);
        long sedeD1 = comparar(f.leche()).getLong("precios.find { it.almacen == 'D1' }.sedeId");
        assertEquals(2, historial(f.leche(), "sedeId", "" + sedeD1).getList("$").size());
        assertEquals(2, historial(f.leche(), "limite", "2").getList("$").size());
    }

    @Test
    void rechazaLimitesInvalidosYProductosInexistentes() {
        var f = TestApi.Fixture.crear();
        given().queryParam("limite", 0).when().get("/api/productos/" + f.leche() + "/historial").then().statusCode(400);
        given().queryParam("limite", 501).when().get("/api/productos/" + f.leche() + "/historial").then().statusCode(400);
        given().when().get("/api/productos/999999999/historial").then().statusCode(404);
    }
}
