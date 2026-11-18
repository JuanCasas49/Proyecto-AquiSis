package org.acme.service;

import org.acme.dto.Dtos.ItemLista;
import org.acme.dto.Dtos.SupermercadoValoracion;
import org.acme.dto.Dtos.Valoracion;
import org.acme.service.ListaService.FilaPrecio;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** HU-07: cálculo del valor de la lista por supermercado y del ahorro (sin base de datos). */
class ValoracionListaTest {

    private static final long LECHE = 1, ARROZ = 2, ACEITE = 3;

    private static BigDecimal n(String v) {
        return new BigDecimal(v);
    }

    private static ItemLista item(long id, String nombre, int cantidad) {
        return new ItemLista(id, nombre, "Marca", "Bolsa", n("1"), "un", false, cantidad);
    }

    private static List<ItemLista> lista() {
        return List.of(item(LECHE, "Leche", 2), item(ARROZ, "Arroz", 1), item(ACEITE, "Aceite", 1));
    }

    private static FilaPrecio fila(long producto, int cantidad, long mercado, String almacen, String precio, Integer dias) {
        return new FilaPrecio(producto, cantidad, mercado, almacen, precio == null ? null : n(precio), "Sede " + almacen,
                "Bogotá", "2026-10-01", dias);
    }

    /** Éxito (completo 25.600), D1 (le falta el aceite, parcial 11.000) y Ara (completo 22.700, aceite de 45 días). */
    private static List<FilaPrecio> escenario() {
        List<FilaPrecio> f = new ArrayList<>();
        f.add(fila(LECHE, 2, 10, "Éxito", "5000", 1));
        f.add(fila(ARROZ, 1, 10, "Éxito", "3600", 1));
        f.add(fila(ACEITE, 1, 10, "Éxito", "12000", 1));
        f.add(fila(LECHE, 2, 20, "D1", "3900", 2));
        f.add(fila(ARROZ, 1, 20, "D1", "3200", 2));
        f.add(fila(ACEITE, 1, 20, "D1", null, null));
        f.add(fila(LECHE, 2, 30, "Ara", "4100", 3));
        f.add(fila(ARROZ, 1, 30, "Ara", "3500", 3));
        f.add(fila(ACEITE, 1, 30, "Ara", "11000", 45));
        return f;
    }

    @Test
    void sumaPrecioPorCantidadEnCadaSupermercado() {
        Valoracion v = ListaService.armar(9, "Semana", lista(), escenario(), null, 30);
        SupermercadoValoracion exito = v.supermercados().stream().filter(m -> m.almacen().equals("Éxito")).findFirst().orElseThrow();
        assertEquals(0, n("25600").compareTo(exito.total()));          // 2x5000 + 3600 + 12000
        assertEquals(0, n("10000").compareTo(exito.lineas().get(0).subtotal()));
        assertEquals(3, exito.productosConPrecio());
        assertEquals(3, v.nProductos());
        assertEquals(4, v.nUnidades());
    }

    @Test
    void ordenaLosComparablesDeMenorAMayorYMarcaElMasEconomico() {
        Valoracion v = ListaService.armar(9, "Semana", lista(), escenario(), null, 30);
        assertEquals(List.of("Ara", "Éxito", "D1"), v.supermercados().stream().map(SupermercadoValoracion::almacen).toList());
        assertTrue(v.supermercados().get(0).esMasEconomico());
        assertFalse(v.supermercados().get(1).esMasEconomico());
        assertEquals(0, n("0").compareTo(v.supermercados().get(0).diferenciaCop()));
        assertEquals(0, n("2900").compareTo(v.supermercados().get(1).diferenciaCop()));
        assertEquals(0, n("12.8").compareTo(v.supermercados().get(1).diferenciaPct()));   // 2900 / 22700
    }

    @Test
    void calculaElAhorroEnPesosYPorcentajeFrenteAlMasCostoso() {
        var r = ListaService.armar(9, "Semana", lista(), escenario(), null, 30).resumen();
        assertEquals(2, r.nComparables());
        assertEquals("Ara", r.masEconomico());
        assertEquals("Éxito", r.masCostoso());
        assertEquals(0, n("22700").compareTo(r.totalMasEconomico()));
        assertEquals(0, n("25600").compareTo(r.totalMasCostoso()));
        assertEquals(0, n("2900").compareTo(r.ahorroCop()));
        assertEquals(0, n("11.3").compareTo(r.ahorroPct()));                              // 2900 / 25600
    }

    @Test
    void unSupermercadoIncompletoSeMuestraParcialYNoEntraEnLaComparacion() {
        Valoracion v = ListaService.armar(9, "Semana", lista(), escenario(), null, 30);
        SupermercadoValoracion d1 = v.supermercados().get(2);
        assertEquals("D1", d1.almacen());
        assertFalse(d1.completo());
        assertEquals(0, n("11000").compareTo(d1.total()));
        assertEquals(List.of("Aceite"), d1.productosSinPrecio());
        assertEquals(2, d1.productosConPrecio());
        assertNull(d1.diferenciaCop());
        assertFalse(d1.esMasEconomico());
        assertNull(d1.lineas().get(2).precioUnitario());          // el aceite no tiene precio en D1
    }

    @Test
    void avisaCuandoUnPrecioUsadoEsAntiguo() {
        Valoracion v = ListaService.armar(9, "Semana", lista(), escenario(), null, 30);
        SupermercadoValoracion ara = v.supermercados().get(0);
        assertTrue(ara.hayDesactualizados());
        assertTrue(ara.lineas().stream().anyMatch(l -> l.productoId() == ACEITE && l.desactualizado() && l.dias() == 45));
        assertFalse(v.supermercados().get(1).hayDesactualizados());
        assertTrue(v.resumen().hayPreciosDesactualizados());
        // con un umbral de 60 días ya no es antiguo
        assertFalse(ListaService.armar(9, "Semana", lista(), escenario(), null, 60).resumen().hayPreciosDesactualizados());
    }

    @Test
    void conUnSoloSupermercadoCompletoNoHayAhorro() {
        List<FilaPrecio> f = new ArrayList<>(escenario().stream().filter(x -> x.establecimientoId() != 30).toList());
        var r = ListaService.armar(9, "Semana", lista(), f, null, 30).resumen();
        assertEquals(1, r.nComparables());
        assertEquals("Éxito", r.masEconomico());
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroCop()));
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroPct()));
    }

    @Test
    void siNingunoEstaCompletoNoSeCalculaAhorro() {
        List<FilaPrecio> f = new ArrayList<>(escenario().stream().filter(x -> x.establecimientoId() == 20).toList());
        Valoracion v = ListaService.armar(9, "Semana", lista(), f, null, 30);
        assertEquals(0, v.resumen().nComparables());
        assertNull(v.resumen().masEconomico());
        assertEquals(0, BigDecimal.ZERO.compareTo(v.resumen().ahorroCop()));
        assertEquals(1, v.supermercados().size());
        assertFalse(v.supermercados().get(0).completo());
    }

    @Test
    void preciosIgualesMarcanAmbosComoMasEconomicos() {
        List<ItemLista> items = List.of(item(LECHE, "Leche", 1));
        List<FilaPrecio> f = List.of(fila(LECHE, 1, 10, "Éxito", "4000", 1), fila(LECHE, 1, 20, "D1", "4000", 1));
        Valoracion v = ListaService.armar(9, "Semana", items, f, null, 30);
        assertTrue(v.supermercados().stream().allMatch(SupermercadoValoracion::esMasEconomico));
        assertEquals(0, BigDecimal.ZERO.compareTo(v.resumen().ahorroCop()));
    }

    @Test
    void informaLosProductosQueNingunSupermercadoTiene() {
        List<ItemLista> items = List.of(item(LECHE, "Leche", 1), item(ARROZ, "Arroz", 1));
        List<FilaPrecio> f = List.of(fila(LECHE, 1, 10, "Éxito", "4000", 1), fila(ARROZ, 1, 10, "Éxito", null, null));
        Valoracion v = ListaService.armar(9, "Semana", items, f, null, 30);
        assertEquals(List.of("Arroz"), v.productosSinPrecioEnNingunSupermercado());
        assertEquals(0, v.resumen().nComparables());
    }

    @Test
    void listaVaciaNoGeneraSupermercadosNiAhorro() {
        Valoracion v = ListaService.armar(9, "Vacía", List.of(), List.of(), null, 30);
        assertTrue(v.supermercados().isEmpty());
        assertEquals(0, v.nProductos());
        assertEquals(0, v.resumen().nComparables());
        assertEquals("Vacía", v.nombre());
    }

    @Test
    void conservaLaCiudadConsultada() {
        assertEquals("Cali", ListaService.armar(9, "S", lista(), List.of(), "Cali", 30).ciudad());
    }
}
