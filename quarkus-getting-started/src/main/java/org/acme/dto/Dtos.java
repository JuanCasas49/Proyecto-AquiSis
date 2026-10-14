package org.acme.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Contratos JSON de la API (camelCase). */
public final class Dtos {

    private Dtos() {
    }

    // ------------------------------------------------------------ entradas --

    public record RegistroProductoRequest(
            @NotBlank(message = "El nombre del producto es obligatorio") @Size(max = 160, message = "El nombre admite máximo 160 caracteres") String nombre,
            @Size(max = 1000, message = "La descripción admite máximo 1000 caracteres") String descripcion,
            @NotBlank(message = "La marca es obligatoria") @Size(max = 80, message = "La marca admite máximo 80 caracteres") String marca,
            @NotBlank(message = "La categoría es obligatoria") @Size(max = 80, message = "La categoría admite máximo 80 caracteres") String categoria,
            @NotBlank(message = "La presentación es obligatoria") @Size(max = 60, message = "La presentación admite máximo 60 caracteres") String presentacion,
            @NotNull(message = "La cantidad es obligatoria") @DecimalMin(value = "0", inclusive = false, message = "La cantidad debe ser mayor que cero") @DecimalMax(value = "9999999", message = "La cantidad es demasiado grande") BigDecimal cantidad,
            @NotBlank(message = "La unidad es obligatoria (g, kg, ml, l, un)") String unidad,
            @NotNull(message = "El precio es obligatorio") @DecimalMin(value = "1", message = "El precio debe ser de al menos $1 COP") @DecimalMax(value = "100000000", message = "El precio no puede superar $100.000.000 COP") BigDecimal precioCop,
            @NotBlank(message = "El almacén es obligatorio") @Size(max = 80, message = "El almacén admite máximo 80 caracteres") String almacen,
            @NotBlank(message = "La sede es obligatoria") @Size(max = 120, message = "La sede admite máximo 120 caracteres") String sede,
            @NotBlank(message = "La ciudad es obligatoria") @Size(max = 80, message = "La ciudad admite máximo 80 caracteres") String ciudad,
            @Size(max = 200, message = "La dirección admite máximo 200 caracteres") String direccion,
            LocalDate fecha,
            @NotNull(message = "Debe identificarse (usuarioId) para reportar precios") Long usuarioId,
            String fotoBase64) {
    }

    public record NuevoPrecioRequest(
            @NotBlank(message = "El almacén es obligatorio") @Size(max = 80, message = "El almacén admite máximo 80 caracteres") String almacen,
            @NotBlank(message = "La sede es obligatoria") @Size(max = 120, message = "La sede admite máximo 120 caracteres") String sede,
            @NotBlank(message = "La ciudad es obligatoria") @Size(max = 80, message = "La ciudad admite máximo 80 caracteres") String ciudad,
            @Size(max = 200, message = "La dirección admite máximo 200 caracteres") String direccion,
            @NotNull(message = "El precio es obligatorio") @DecimalMin(value = "1", message = "El precio debe ser de al menos $1 COP") @DecimalMax(value = "100000000", message = "El precio no puede superar $100.000.000 COP") BigDecimal precioCop,
            LocalDate fecha,
            @NotNull(message = "Debe identificarse (usuarioId) para reportar precios") Long usuarioId) {
    }

    public record UsuarioRequest(
            @NotBlank(message = "El nombre es obligatorio") @Size(min = 2, max = 80, message = "El nombre debe tener entre 2 y 80 caracteres") String nombre,
            @NotBlank(message = "El correo es obligatorio") @Email(message = "El correo no es válido") @Size(max = 160, message = "El correo admite máximo 160 caracteres") String email) {
    }

    // ------------------------------------------------------------ salidas ---

    public record UsuarioResponse(long id, String nombre, String email) {
    }

    public record RegistroResponse(long productoId, long reporteId, boolean productoNuevo) {
    }

    public record Opcion(long id, String nombre) {
    }

    public record SedeDto(long id, long establecimientoId, String almacen, String nombre, String ciudad, String direccion) {
    }

    public record ProductoResumen(
            long id, String nombre, String marca, String categoria, String presentacion,
            BigDecimal cantidad, String unidad, boolean tieneFoto,
            BigDecimal precioMin, BigDecimal precioMax, int nSedes,
            String ultimaFecha, Integer diasUltima, boolean desactualizado,
            String mejorAlmacen, String mejorSede, String mejorCiudad) {
    }

    public record PaginaProductos(List<ProductoResumen> items, long total, int pagina, int tamano) {
    }

    public record ProductoDetalle(
            long id, String nombre, String descripcion, String marca, String categoria,
            long marcaId, long categoriaId, String presentacion, BigDecimal cantidad, String unidad,
            boolean tieneFoto, String creadoPor, String creadoEn) {
    }

    public record PrecioSede(
            long reporteId, long sedeId, long establecimientoId, String almacen, String sede, String ciudad,
            String direccion, BigDecimal precioCop, String fecha, int dias, boolean desactualizado,
            boolean esMasBarato, BigDecimal diferenciaCop, BigDecimal diferenciaPct) {
    }

    public record ResumenComparacion(
            int nSedes, BigDecimal precioMinimo, BigDecimal precioMaximo, BigDecimal precioPromedio,
            PrecioSede masEconomico, PrecioSede masCaro,
            BigDecimal ahorroMaximoCop, BigDecimal ahorroMaximoPct,
            int unidades, BigDecimal ahorroTotalCop, BigDecimal ahorroVsPromedioCop,
            boolean masEconomicoDesactualizado, boolean hayPreciosDesactualizados) {
    }

    public record Comparacion(ProductoDetalle producto, List<PrecioSede> precios,
                              ResumenComparacion resumen, int diasVigencia) {
    }

    public record Reporte(
            long reporteId, long sedeId, String almacen, String sede, String ciudad,
            BigDecimal precioCop, String fecha, int dias, boolean desactualizado,
            String usuario, BigDecimal variacionCop) {
    }

    public record Foto(byte[] datos, String tipo) {
    }
}
