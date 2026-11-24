"""Banco 1.9.4 / sqlclass6 v6.4 (11/11/2026): arma 3 TXA de un sistema multi-DLL chico, SOLO para generar y compilar
(no se ejecutan, no necesitan servidor).
  python make-conexion-txa.py <carpeta-salida>
Escribe:
  SqDat.txa  DLL duena de los objetos globales: SQL (guardado con motor 'SQL Server directo', Conexion vacia: caso a)
             y SQLD ('SQL Server directo', Conexion vacia: caso c). Exporta $SQL y SQLD$MSDIRECT.
  SqDaB.txa  DLL con un solo objeto SQL (guardado con 'SQL Server directo') y Conexion Glo:OwnerName (caso b): .Init, no .InitDirect.
  TcwEx.txa  EXE con los datos globales externos (de SqDat.dll) y un TCW_Display por caso:
             Main  = d  SQLCLASS MSSQL sin tocar nada mas      -> SQLD SQLMsDirectClass, SQLD.InitDirect(SQL.PropOwner)
             PrE   = e  SQLCLASS con Instancia SQLD (global directo) -> sin declaracion, ErrorText
             PrF   = f  SQLCLASS con Instancia SQL (driver)  -> sin ErrorText
             PrG   = g  viejo: SQLCLASS MSSQL + %TCWUsarGlobal=1 + %TCWCLASS SQL -> como f
             PrH   = h  viejo: SQLCLASS MSSQL, %TCWUsarGlobal=0, %TCWCLASS SQLM (instancia local de otro nombre) -> SQLM
Los prompts de las columnas salen de templates\\desab\\sotsrvDSP_Cheques_Diferidos.txa (como make-tcwtest-txa.py).
"""
import re
import sys
from pathlib import Path

salida = Path(sys.argv[1])
raiz = Path(__file__).resolve()
base = next(p / "desab" / "sotsrvDSP_Cheques_Diferidos.txa" for p in raiz.parents
            if (p / "desab" / "sotsrvDSP_Cheques_Diferidos.txa").exists())
src = base.read_bytes().decode("cp1252").replace("\r\n", "\n").split("\n")
ini = next(i for i, x in enumerate(src) if x.startswith("%TCWVersion "))
fin = next(i for i, x in enumerate(src) if x.startswith("%PreserveSection "))
base_prompts = "\n".join(src[ini:fin]).rstrip("\n")
base_prompts = re.sub(r"^%DoTCWRefresh LONG .*$", "%DoTCWRefresh LONG  (1)", base_prompts, flags=re.M)
base_prompts = re.sub(r"^%TCWUSADgb LONG .*$", "%TCWUSADgb LONG  (0)", base_prompts, flags=re.M)


def apagar(texto, simbolo):
    m = re.search(r"^" + simbolo + r" DEPEND .*?(?=^\n|^%)", texto, flags=re.M | re.S)
    bloque = re.sub(r"\((1)\)$", "(0)", m.group(0), flags=re.M)
    return texto.replace(m.group(0), bloque)


base_prompts = apagar(base_prompts, "%TCWFUNDDATE")
base_prompts = apagar(base_prompts, "%TCWIconUse")
base_prompts += ("\n%TCWDisableSort LONG  (0)"
                 "\n%dxMode DEFAULT  ('The LIST (as TCW_Display)')"
                 "\n%dxResize LONG  (0)")


def prompts_tcw(filetable, extra):
    p = re.sub(r"^%TCWFileTable DEFAULT .*$", "%TCWFileTable DEFAULT  ('" + filetable + "')", base_prompts, flags=re.M)
    p = re.sub(r"^%TCWCLASS DEFAULT .*\n", "", p, flags=re.M)      # se agrega abajo si el caso lo guarda
    for k, v in extra.items():
        p += f"\n{k} {v}"
    return p


cols = []
for n in range(1, 51):
    cols += [f"Col{n}                       CSTRING(255)",
             f"Col{n}_NormalFG              LONG",
             f"Col{n}_NormalBG              LONG",
             f"Col{n}_SelectedFG            LONG",
             f"Col{n}_SelectedBG            LONG",
             f"Col{n}_Icon                  LONG"]
datos = "\n".join([
    "L:EvoFormat              STRING(10000)",
    "L:EvoQuery               CSTRING(10000)",
    "L:EvoRightBorder         BYTE",
    "L:EvoUnderline           BYTE",
    "L:Evo_Tot_Reg            LONG",
    "L_Error                  BYTE",
    "SearchName               STRING(100)",
    "SearchNameCopy           STRING(100)",
    "QDATA_TOTAL              DECIMAL(20,4),DIM(50)",
    "QData                    QUEUE,PRE(Qdat)",
    *cols,
    "                         END",
])
campos = ",".join(f"Qdat:Col{n}" for n in range(1, 21))
formato = "".join(f"55L(2)|M~Col {n}~L(0)@s20@" for n in range(1, 21))


def procedimiento(nombre, filetable, extra):
    return f"""[PROCEDURE]
NAME {nombre}
[COMMON]
FROM TCWDSPSQL TCWSQLprocedure
MODIFIED '2026/11/11' '12:00:00'
[DATA]
{datos}
[PROMPTS]
{prompts_tcw(filetable, extra)}
[EMBED]
EMBED %BeforeSQLQuery
[DEFINITION]
[SOURCE]
PROPERTY:BEGIN
PRIORITY 4000
PROPERTY:END
  L:EvoQuery = 'SELECT 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 FROM Cbtes'
[END]
[END]
[WINDOW]
BrowseWindow WINDOW('Caso {nombre}'),AT(,,600,300),FONT('MS Sans Serif',8,,FONT:regular),CENTER,GRAY,SYSTEM,TIMER(50)
          LIST,AT(6,20,588,270),USE(?List1),HVSCROLL,FORMAT('{formato}'),FROM(QData),#FIELDS({campos}),#ORDINAL(1)
          BUTTON('&Salir'),AT(540,2,52,14),USE(?EvoExit),#ORDINAL(2)
        END
[END]
"""


def extension(objetos, externo):
    n = len(objetos)
    idx = ", ".join(str(i + 1) for i in range(n))
    def dep(sym, vals):
        s = f"{sym} DEPEND %QTodosLosSQL DEFAULT TIMES {n}\n"
        for i, v in enumerate(vals):
            s += f"WHEN  ({i + 1}) ('{v}')\n"
        return s
    return f"""[ADDITION]
NAME SqlClass SQLClass
[INSTANCE]
INSTANCE 1
[PROMPTS]
%QDriver DEFAULT  ('MsSQL')
%QDriverFromAppOpt LONG  (0)
%QDriverLocal DEFAULT  ('MsSQL')
%QTablaSQL DEFAULT  ('SQLClass')
%QMaxFields DEFAULT  ('20')
%QFieldSize DEFAULT  ('50')
%QUsaStringTheory LONG  (0)
%QIncluyeMsDirect LONG  (0)
%QMaxRegistros LONG  (0)
%QCantMaxRegistros DEFAULT  ('500')
%QTodosLosSQL MULTI LONG  ({idx})
{dep('%QMiSQL', [o[0] for o in objetos])}{dep('%QMiSQLMotor', [o[1] for o in objetos])}{dep('%QMiSQLConexion', [o[2] for o in objetos])}
"""


def app(nombre, dll, externo, objetos, procs, global_data=""):
    procs_txt = ""
    modules = ""
    compiles = f'#compile "{nombre}.clw" -- GENERATED\n'
    for i, (pn, ft, ex) in enumerate(procs, 1):
        mod = f"{nombre}{i:03d}.clw"
        compiles += f'#compile "{mod}" -- GENERATED\n'
        modules += f"""[MODULE]
NAME '{mod}'
[COMMON]
FROM ABC GENERATED
MODIFIED '2026/11/11' '12:00:00'
{procedimiento(pn, ft, ex)}"""
    if externo:
        gp = """%GlobalExternal LONG  (1)
%ExternalSource DEFAULT  ('Dynamic Link Library (DLL)')
%DefaultGenerate LONG  (0)
%DefaultExternal DEFAULT  ('All External')
%DefaultExternalAPP LONG  (1)
%DefaultExport LONG  (0)
"""
    else:
        gp = """%GlobalExternal LONG  (0)
%DefaultGenerate LONG  (1)
%DefaultExternal DEFAULT  ('None External')
%DefaultExport LONG  (1)
"""
    head = "PROCEDURE Main\n" if procs else ""
    datos_g = f"[DATA]\n{global_data}\n" if global_data else ""
    txa = f"""[APPLICATION]
VERSION 34
TODO ABC ToDo
{head}[COMMON]
FROM ABC
MODIFIED '2026/11/11' '12:00:00'
[PROMPTS]
{gp}{extension(objetos, externo)}[PROJECT]
#noedit
#system win32 {'dll' if dll else 'exe'}
#model clarion dll
{compiles}#link "{nombre}.{'DLL' if dll else 'exe'}"
[PROGRAM]
NAME '{nombre}.clw'
[COMMON]
FROM ABC ABC
MODIFIED '2026/11/11' '12:00:00'
{datos_g}[END]
{modules}"""
    (salida / f"{nombre}.txa").write_bytes(txa.replace("\n", "\r\n").encode("cp1252"))
    print("ok", salida / f"{nombre}.txa")


DUENO = [("SQL", "SQL Server directo", ""), ("SQLD", "SQL Server directo", "")]   # SQL guardado con directo (app vieja)
app("SqDat", True, False, DUENO, [])
app("SqDaB", True, False, [("SQL", "SQL Server directo", "Glo:OwnerName")], [],   # b: guardado directo como en SQPEXP
    "Glo:OwnerName            CSTRING(255)")
app("TcwEx", False, True, DUENO, [
    ("Main", "SQLCLASS MSSQL", {}),                                              # d: nada mas tocado
    ("PrE", "SQLCLASS", {"%TCWCLASS": "DEFAULT  ('SQLD')"}),                     # e
    ("PrF", "SQLCLASS", {"%TCWCLASS": "DEFAULT  ('SQL')"}),                      # f
    ("PrG", "SQLCLASS MSSQL", {"%TCWCLASS": "DEFAULT  ('SQL')", "%TCWUsarGlobal": "LONG  (1)",
                               "%TCWConexion": "DEFAULT  ('')"}),                # g: legado
    ("PrH", "SQLCLASS MSSQL", {"%TCWCLASS": "DEFAULT  ('SQLM')", "%TCWUsarGlobal": "LONG  (0)",
                               "%TCWConexion": "DEFAULT  ('')"}),                # h: legado, local SQLM
])
