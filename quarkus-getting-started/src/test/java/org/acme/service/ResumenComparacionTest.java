package org.acme.service;

import org.acme.dto.Dtos.PrecioSede;
import org.acme.dto.Dtos.ResumenComparacion;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Prueba unitaria (sin base de datos) del cálculo de ahorros del comparador. */
class ResumenComparacionTest {

    private static PrecioSede sede(String almacen, String precio, int dias, boolean desactualizado, boolean barato) {
        return new PrecioSede(1, 1, 1, almacen, almacen + " Centro", "Bogotá", null, new BigDecimal(precio),
                "2026-10-01", dias, desactualizado, barato, BigDecimal.ZERO, null);
    }

    @Test
    void identificaMasEconomicoMasCaroYCalculaAhorro() {
        List<PrecioSede> filas = List.of(
                sede("D1", "3900", 2, false, true),
                sede("Ara", "4100", 5, false, false),
                sede("Éxito", "5000", 1, false, false));

        ResumenComparacion r = ProductoService.resumir(filas, 1);

        assertEquals(3, r.nSedes());
        assertEquals("D1", r.masEconomico().almacen());
        assertEquals("Éxito", r.masCaro().almacen());
        assertEquals(0, new BigDecimal("3900").compareTo(r.precioMinimo()));
        assertEquals(0, new BigDecimal("5000").compareTo(r.precioMaximo()));
        assertEquals(0, new BigDecimal("1100").compareTo(r.ahorroMaximoCop()));
        assertEquals(0, new BigDecimal("22.0").compareTo(r.ahorroMaximoPct()));   // 1100 / 5000
        assertEquals(0, new BigDecimal("4333.33").compareTo(r.precioPromedio()));
        assertEquals(0, new BigDecimal("433.33").compareTo(r.ahorroVsPromedioCop()));
    }

    @Test
    void ahorroTotalSeMultiplicaPorLasUnidades() {
        List<PrecioSede> filas = List.of(sede("D1", "3900", 2, false, true), sede("Éxito", "5000", 1, false, false));
        ResumenComparacion r = ProductoService.resumir(filas, 10);
        assertEquals(10, r.unidades());
        assertEquals(0, new BigDecimal("11000").compareTo(r.ahorroTotalCop()));
    }

    @Test
    void conUnaSolaSedeNoHayAhorro() {
        ResumenComparacion r = ProductoService.resumir(List.of(sede("D1", "3900", 2, false, true)), 3);
        assertEquals(1, r.nSedes());
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroMaximoCop()));
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroTotalCop()));
        assertEquals("D1", r.masEconomico().almacen());
        assertEquals("D1", r.masCaro().almacen());
    }

    @Test
    void advierteCuandoElMasBaratoOAlgunPrecioEstaDesactualizado() {
        ResumenComparacion viejoBarato = ProductoService.resumir(List.of(
                sede("D1", "1000", 45, true, true), sede("Éxito", "5000", 1, false, false)), 1);
        assertTrue(viejoBarato.masEconomicoDesactualizado());
        assertTrue(viejoBarato.hayPreciosDesactualizados());

        ResumenComparacion viejoCaro = ProductoService.resumir(List.of(
                sede("D1", "1000", 1, false, true), sede("Éxito", "5000", 60, true, false)), 1);
        assertFalse(viejoCaro.masEconomicoDesactualizado());
        assertTrue(viejoCaro.hayPreciosDesactualizados());

        ResumenComparacion vigentes = ProductoService.resumir(List.of(
                sede("D1", "1000", 1, false, true), sede("Éxito", "5000", 3, false, false)), 1);
        assertFalse(vigentes.hayPreciosDesactualizados());
    }

    @Test
    void preciosIgualesNoGeneranAhorro() {
        ResumenComparacion r = ProductoService.resumir(List.of(
                sede("D1", "2000", 1, false, true), sede("Ara", "2000", 1, false, true)), 1);
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroMaximoCop()));
        assertEquals(0, BigDecimal.ZERO.compareTo(r.ahorroMaximoPct()));
    }
}
