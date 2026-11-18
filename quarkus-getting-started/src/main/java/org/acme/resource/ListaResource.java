package org.acme.resource;

import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.acme.dto.Dtos.CantidadRequest;
import org.acme.dto.Dtos.ItemLista;
import org.acme.dto.Dtos.ItemListaRequest;
import org.acme.dto.Dtos.ListaDetalle;
import org.acme.dto.Dtos.ListaRequest;
import org.acme.dto.Dtos.ListaResumen;
import org.acme.dto.Dtos.Valoracion;
import org.acme.service.ListaService;

import java.util.List;

/**
 * HU-06 y HU-07. Sin autenticación real: el dueño de la lista se indica con usuarioId
 * (query en GET/DELETE, cuerpo en POST/PUT) y una lista ajena responde 404.
 */
@Path("/api/listas")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ListaResource {

    @Inject
    ListaService service;

    @GET
    public List<ListaResumen> listar(@QueryParam("usuarioId") Long usuarioId) {
        return service.listar(usuarioId);
    }

    @POST
    public Response crear(@Valid ListaRequest request) {
        return Response.status(Response.Status.CREATED).entity(service.crear(request)).build();
    }

    @GET
    @Path("/{id}")
    public ListaDetalle detalle(@PathParam("id") long id, @QueryParam("usuarioId") Long usuarioId) {
        return service.detalle(id, usuarioId);
    }

    @PUT
    @Path("/{id}")
    public ListaResumen renombrar(@PathParam("id") long id, @Valid ListaRequest request) {
        return service.renombrar(id, request);
    }

    @DELETE
    @Path("/{id}")
    public Response eliminar(@PathParam("id") long id, @QueryParam("usuarioId") Long usuarioId) {
        service.eliminar(id, usuarioId);
        return Response.noContent().build();
    }

    /** Agrega un producto (si ya estaba, suma la cantidad). */
    @POST
    @Path("/{id}/items")
    public Response agregarItem(@PathParam("id") long id, @Valid ItemListaRequest request) {
        return Response.status(Response.Status.CREATED).entity(service.agregarItem(id, request)).build();
    }

    /** Cambia la cantidad de un producto de la lista. */
    @PUT
    @Path("/{id}/items/{productoId}")
    public ItemLista modificarCantidad(@PathParam("id") long id, @PathParam("productoId") long productoId,
                                       @Valid CantidadRequest request) {
        return service.modificarCantidad(id, productoId, request);
    }

    @DELETE
    @Path("/{id}/items/{productoId}")
    public Response quitarItem(@PathParam("id") long id, @PathParam("productoId") long productoId,
                               @QueryParam("usuarioId") Long usuarioId) {
        service.quitarItem(id, productoId, usuarioId);
        return Response.noContent().build();
    }

    /** HU-07: total por supermercado y ahorro frente al más costoso. */
    @GET
    @Path("/{id}/valoracion")
    public Valoracion valoracion(@PathParam("id") long id, @QueryParam("usuarioId") Long usuarioId,
                                 @QueryParam("ciudad") String ciudad) {
        return service.valoracion(id, usuarioId, ciudad);
    }
}
