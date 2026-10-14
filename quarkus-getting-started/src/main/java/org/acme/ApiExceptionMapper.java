package org.acme;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

import java.util.Map;
import java.util.TreeSet;
import java.util.stream.Collectors;

/** Convierte las excepciones de la API en respuestas JSON {"error": "..."} uniformes. */
public class ApiExceptionMapper {

    @ServerExceptionMapper
    public Response api(ApiException e) {
        return respuesta(e.getStatus(), e.getMessage());
    }

    @ServerExceptionMapper
    public Response validacion(ConstraintViolationException e) {
        String mensaje = new TreeSet<>(e.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .collect(Collectors.toList())).stream().collect(Collectors.joining("; "));
        return respuesta(400, mensaje.isBlank() ? "Datos inválidos" : mensaje);
    }

    private static Response respuesta(int status, String mensaje) {
        return Response.status(status).type(MediaType.APPLICATION_JSON)
                .entity(Map.of("error", mensaje)).build();
    }
}
