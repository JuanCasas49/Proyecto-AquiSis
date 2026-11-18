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
import org.acme.dto.Dtos.Foto;
import org.acme.dto.Dtos.ModeradorRequest;
import org.acme.dto.Dtos.RechazoRequest;
import org.acme.dto.Dtos.ReporteUsuario;
import org.acme.dto.Dtos.ResultadoModeracion;
import org.acme.service.PrecioService;

import java.util.List;

/** HU-08: evidencia fotográfica y validación de precios reportados (solo moderadores validan o rechazan). */
@Path("/api/precios")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class PrecioResource {

    @Inject
    PrecioService service;

    /** Cola de moderación. Requiere usuarioId de un moderador. */
    @GET
    @Path("/pendientes")
    public List<ReporteUsuario> pendientes(@QueryParam("usuarioId") Long usuarioId,
                                           @QueryParam("limite") @DefaultValue("50") int limite) {
        return service.pendientes(usuarioId, limite);
    }

    @POST
    @Path("/{id}/validar")
    public ResultadoModeracion validar(@PathParam("id") long id, @Valid ModeradorRequest request) {
        return service.validar(id, request.usuarioId());
    }

    @POST
    @Path("/{id}/rechazar")
    public ResultadoModeracion rechazar(@PathParam("id") long id, @Valid RechazoRequest request) {
        return service.rechazar(id, request.usuarioId(), request.motivo());
    }

    @GET
    @Path("/{id}/evidencia")
    @Produces(MediaType.WILDCARD)
    public Response evidencia(@PathParam("id") long id) {
        Foto f = service.evidencia(id);
        return Response.ok(f.datos(), f.tipo()).header("Cache-Control", "public, max-age=3600").build();
    }
}
