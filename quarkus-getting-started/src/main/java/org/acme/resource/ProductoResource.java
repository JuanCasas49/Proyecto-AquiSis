package org.acme.resource;

import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.acme.dto.Dtos.Comparacion;
import org.acme.dto.Dtos.Foto;
import org.acme.dto.Dtos.NuevoPrecioRequest;
import org.acme.dto.Dtos.PaginaProductos;
import org.acme.dto.Dtos.ProductoDetalle;
import org.acme.dto.Dtos.RegistroProductoRequest;
import org.acme.dto.Dtos.RegistroResponse;
import org.acme.dto.Dtos.Reporte;
import org.acme.service.ProductoService;

import java.math.BigDecimal;
import java.util.List;

@Path("/api/productos")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ProductoResource {

    @Inject
    ProductoService service;

    /** Catálogo con búsqueda y filtros combinables. */
    @GET
    public PaginaProductos listar(@QueryParam("q") String q,
                                  @QueryParam("categoriaId") Long categoriaId,
                                  @QueryParam("marcaId") Long marcaId,
                                  @QueryParam("establecimientoId") Long establecimientoId,
                                  @QueryParam("ciudad") String ciudad,
                                  @QueryParam("precioMin") BigDecimal precioMin,
                                  @QueryParam("precioMax") BigDecimal precioMax,
                                  @QueryParam("orden") String orden,
                                  @QueryParam("pagina") @DefaultValue("1") int pagina,
                                  @QueryParam("tamano") @DefaultValue("20") int tamano) {
        return service.buscar(q, categoriaId, marcaId, establecimientoId, ciudad, precioMin, precioMax,
                orden, pagina, tamano);
    }

    /** Registra un producto (o reutiliza el existente) junto con su primer precio. */
    @POST
    public Response registrar(@Valid RegistroProductoRequest request) {
        RegistroResponse r = service.registrar(request);
        return Response.status(r.productoNuevo() ? Response.Status.CREATED : Response.Status.OK).entity(r).build();
    }

    @GET
    @Path("/{id}")
    public ProductoDetalle detalle(@PathParam("id") long id) {
        return service.detalle(id);
    }

    /** Precios por sede de menor a mayor, más económico, diferencias y ahorros. */
    @GET
    @Path("/{id}/comparacion")
    public Comparacion comparar(@PathParam("id") long id,
                                @QueryParam("ciudad") String ciudad,
                                @QueryParam("establecimientoId") Long establecimientoId,
                                @QueryParam("unidades") @DefaultValue("1") int unidades) {
        return service.comparar(id, ciudad, establecimientoId, unidades);
    }

    @GET
    @Path("/{id}/historial")
    public List<Reporte> historial(@PathParam("id") long id,
                                   @QueryParam("sedeId") Long sedeId,
                                   @QueryParam("limite") @DefaultValue("100") int limite) {
        return service.historial(id, sedeId, limite);
    }

    /** Agrega un nuevo reporte de precio a un producto existente. */
    @POST
    @Path("/{id}/precios")
    public Response agregarPrecio(@PathParam("id") long id, @Valid NuevoPrecioRequest request) {
        return Response.status(Response.Status.CREATED).entity(service.agregarPrecio(id, request)).build();
    }

    @GET
    @Path("/{id}/foto")
    @Produces(MediaType.WILDCARD)
    public Response foto(@PathParam("id") long id) {
        Foto f = service.foto(id);
        return Response.ok(f.datos(), f.tipo()).header("Cache-Control", "public, max-age=3600").build();
    }
}
