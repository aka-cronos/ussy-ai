# UssyAi

UssyAi permite consultar las cuotas de suscripción de servicios de inteligencia artificial y sus reinicios.

## Language

**Cuota de suscripción**:
Límite de uso que un proveedor aplica a una suscripción durante un periodo determinado. Es distinto del gasto monetario y del consumo facturado de una API.
_Avoid_: Saldo, créditos, consumo (sin especificar qué se mide).

**Cuota usada**:
Parte de una cuota de suscripción que ya se ha consumido dentro del periodo correspondiente.
_Avoid_: Gasto, costo.

**Cuota restante**:
Parte de una cuota de suscripción que sigue disponible dentro del periodo correspondiente.
_Avoid_: Dinero disponible, saldo.

**Reinicio**:
Momento indicado por el proveedor en que se renueva una cuota de suscripción.
_Avoid_: Recarga, renovación de sesión.

**Último dato válido**:
Información de una cuota de suscripción obtenida en la última consulta válida para una cuenta concreta, junto con el momento de esa consulta. Tras un fallo de actualización, es un dato desactualizado y no confirma la cuota actual.
_Avoid_: Cuota actual (cuando no se ha podido actualizar), dato de otra cuenta.

**Periodo de cuota**:
Intervalo al que corresponden el uso y el límite de una cuota de suscripción. Cuotas de periodos distintos son independientes aunque pertenezcan al mismo proveedor.
_Avoid_: Mes calendario (cuando se trata de un ciclo de facturación), periodo combinado.

**Dato calculado**:
Valor de una cuota obtenido a partir de otros datos válidos de esa misma cuota, cuenta, unidad y periodo, en lugar de comunicado directamente por el proveedor.
_Avoid_: Dato reportado por el proveedor (cuando es calculado), estimación (para un cálculo exacto).
