"""Preparacion para imprimir. Un horario acaba pegado en la pared, asi que sale
apaisado y ajustado al ancho de una pagina."""
from openpyxl.worksheet.properties import PageSetupProperties


def preparar(ws, filas_encabezado: str | None = None,
             apaisado: bool = True) -> None:
    """Deja `ws` lista para imprimir: ajustada al ancho de una pagina y, si se
    indica, repitiendo `filas_encabezado` (p. ej. "1:3") arriba de cada pagina.

    `apaisado` decide la orientacion. Las rejillas van apaisadas porque son
    anchas; la portada se lee en vertical, pero necesita el ajuste al ancho
    igual: sin el, una ruta de origen larga ensancha la hoja mas que el papel y
    el texto se corta.

    `fitToWidth` se ignora en silencio si `pageSetUpPr.fitToPage` no esta
    activo: hay que poner los dos.
    """
    ws.page_setup.orientation = "landscape" if apaisado else "portrait"

    # Una hoja nueva ya trae un objeto `pageSetUpPr` (con todo en None). Se
    # muta ese objeto en vez de reemplazarlo por uno nuevo para no pisar otros
    # atributos (p. ej. `autoPageBreaks`) que otro modulo pudiera haber fijado
    # antes de llamar a `preparar`.
    propiedades = ws.sheet_properties.pageSetUpPr
    if propiedades is None:
        propiedades = PageSetupProperties()
        ws.sheet_properties.pageSetUpPr = propiedades
    propiedades.fitToPage = True

    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0      # 0 = tantas paginas de alto como haga falta
    if filas_encabezado:
        ws.print_title_rows = filas_encabezado
