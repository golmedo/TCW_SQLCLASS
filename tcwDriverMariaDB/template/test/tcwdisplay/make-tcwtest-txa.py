"""Genera TcwTest.txa: una app con un procedimiento TCW_Display (File of procedure = SQLCLASS MariaDB o SQLCLASS MSSQL).
Los prompts de las 14 columnas salen de un procedimiento real (desab\\sotsrvDSP_Cheques_Diferidos.txa).
Al abrir, el procedimiento carga la consulta; en el primer Timer escribe en resultado.txt las filas cargadas y un
COUNT(*) hecho con la misma instancia, y se cierra.
  python make-tcwtest-txa.py MariaDB|MSSQL salida.txa [heredar]
Con 'heredar' la app lleva la extension global SQLClass con un objeto SQLG (motor directo, se conecta solo al
iniciar) y el procedimiento deja Conexion vacia: tiene que heredar SQLG.PropOwner.
"""
import re
import sys
from pathlib import Path

motor, salida = sys.argv[1], Path(sys.argv[2])
heredar = len(sys.argv) > 3 and sys.argv[3] == "heredar"
base = Path(__file__).resolve().parents[4] / "desab" / "sotsrvDSP_Cheques_Diferidos.txa"
src = base.read_bytes().decode("cp1252").replace("\r\n", "\n").split("\n")

# prompts de TCW: desde %TCWVersion hasta el bloque de %TCWIconId (incluido)
ini = next(i for i, x in enumerate(src) if x.startswith("%TCWVersion "))
fin = next(i for i, x in enumerate(src) if x.startswith("%PreserveSection "))
prompts = "\n".join(src[ini:fin]).rstrip("\n")
prompts = re.sub(r"^%TCWFileTable DEFAULT .*$", "%TCWFileTable DEFAULT  ('SQLCLASS " + motor + "')", prompts, flags=re.M)
prompts = re.sub(r"^%TCWCLASS DEFAULT .*$", "%TCWCLASS DEFAULT  ('SQLD')", prompts, flags=re.M)
prompts = re.sub(r"^%DoTCWRefresh LONG .*$", "%DoTCWRefresh LONG  (0)", prompts, flags=re.M)
prompts = re.sub(r"^%TCWUSADgb LONG .*$", "%TCWUSADgb LONG  (0)", prompts, flags=re.M)


def apagar(texto, simbolo):
    """Pone en 0 todos los WHEN de un prompt DEPEND LONG (fun_DDate, iconos)."""
    m = re.search(r"^" + simbolo + r" DEPEND .*?(?=^\n|^%)", texto, flags=re.M | re.S)
    bloque = re.sub(r"\((1)\)$", "(0)", m.group(0), flags=re.M)
    return texto.replace(m.group(0), bloque)


prompts = apagar(prompts, "%TCWFUNDDATE")
prompts = apagar(prompts, "%TCWIconUse")
INI = "GETINI(''Conexion'',''Cadena'','''',LONGPATH() & ''\\TcwTest.ini'')"
prompts += ("\n%TCWConexion DEFAULT  ('" + ("" if heredar else INI) + "')"
            "\n%TCWDisableSort LONG  (0)"
            "\n%dxMode DEFAULT  ('The LIST (as TCW_Display)')"
            "\n%dxResize LONG  (0)")   # la app de prueba no tiene frame MDI

if motor == "MariaDB":
    consulta = ("SELECT Fecha, Descripcion, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 "
                "FROM cbtes WHERE Fecha >= ''2026-10-01'' ORDER BY Fecha")
    cuenta = "SELECT COUNT(*) FROM cbtes WHERE Fecha >= ''2026-10-01''"
else:
    consulta = ("SELECT CONVERT(varchar(10), Fecha, 120), IdTransaccion, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 "
                "FROM Cbtes WHERE Fecha >= ''2026-10-01'' ORDER BY Fecha")
    cuenta = "SELECT COUNT(*) FROM Cbtes WHERE Fecha >= ''2026-10-01''"

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
    "L_Hecho                  BYTE",
    "SearchName               STRING(100)",
    "SearchNameCopy           STRING(100)",
    "QDATA_TOTAL              DECIMAL(20,4),DIM(50)",
    "QData                    QUEUE,PRE(Qdat)",
    *cols,
    "                         END",
])
campos = ",".join(f"Qdat:Col{n}" for n in range(1, 21))
formato = "".join(f"55L(2)|M~Col {n}~L(0)@s20@" for n in range(1, 21))

global_ext = ""
if heredar:
    driver = "MSSQL" if motor == "MSSQL" else "ODBC"
    global_ext = f"""[ADDITION]
NAME SqlClass SQLClass
[INSTANCE]
INSTANCE 1
[PROMPTS]
%QDriver DEFAULT  ('{driver}')
%QDriverFromAppOpt LONG  (0)
%QDriverLocal DEFAULT  ('{driver}')
%QTablaSQL DEFAULT  ('sqlclass')
%QMaxFields DEFAULT  ('20')
%QFieldSize DEFAULT  ('50')
%QUsaStringTheory LONG  (0)
%QMaxRegistros LONG  (0)
%QCantMaxRegistros DEFAULT  ('500')
%QTodosLosSQL MULTI LONG  (1)
%QMiSQL DEPEND %QTodosLosSQL DEFAULT TIMES 1
WHEN  (1) ('SQLG')
%QMiSQLMotor DEPEND %QTodosLosSQL DEFAULT TIMES 1
WHEN  (1) ('{"SQL Server directo" if motor == "MSSQL" else "MariaDB directo"}')
%QMiSQLConexion DEPEND %QTodosLosSQL DEFAULT TIMES 1
WHEN  (1) ('{INI}')

"""
txa = f"""[APPLICATION]
VERSION 34
TODO ABC ToDo
PROCEDURE Main
[COMMON]
FROM ABC
MODIFIED '2026/10/29' '12:00:00'
{global_ext}[PROJECT]
#noedit
#system win32 exe
#model clarion dll
#compile "TcwTest.clw" -- GENERATED
#compile "TcwTest001.clw" -- GENERATED
#link "TcwTest.exe"
[PROGRAM]
NAME 'TcwTest.clw'
[COMMON]
FROM ABC ABC
MODIFIED '2026/10/29' '12:00:00'
[END]
[MODULE]
NAME 'TcwTest001.clw'
[COMMON]
FROM ABC GENERATED
MODIFIED '2026/10/29' '12:00:00'
[PROCEDURE]
NAME Main
[COMMON]
FROM TCWDSPSQL TCWSQLprocedure
MODIFIED '2026/10/29' '12:00:00'
[DATA]
{datos}
[PROMPTS]
{prompts}
[EMBED]
EMBED %BeforeSQLQuery
[DEFINITION]
[SOURCE]
PROPERTY:BEGIN
PRIORITY 4000
PROPERTY:END
  SQLD.LogFile = LONGPATH() & '\\resultado.txt'
  L:EvoQuery = '{consulta}'
[END]
EMBED %WindowEventHandling
[INSTANCES]
WHEN 'Timer'
[DEFINITION]
[SOURCE]
PROPERTY:BEGIN
PRIORITY 6000
PROPERTY:END
  IF NOT L_Hecho
    L_Hecho = 1
    SQLD.WriteLog('TCW filas cargadas: ' & RECORDS(QData))
    IF RECORDS(QData)
      GET(QData,1)
      SQLD.WriteLog('TCW primera fila: ' & Qdat:Col1 & ' | ' & Qdat:Col2 & ' | ' & Qdat:Col14)
    END
    SQLD.WriteLog('TCW COUNT(*) del servidor: ' & SQLD.Fetch(1,'{cuenta}'))
    SQLD.WriteLog('TCW servidor: ' & SQLD.ServerVersion())
    SQLD.WriteLog('FIN')
    POST(EVENT:CloseWindow)
  END
[END]
[END]
[END]
[WINDOW]
BrowseWindow WINDOW('Prueba TCW_Display {motor}'),AT(,,600,300),FONT('MS Sans Serif',8,,FONT:regular),CENTER,GRAY,SYSTEM,TIMER(50)
          LIST,AT(6,20,588,270),USE(?List1),HVSCROLL,FORMAT('{formato}'),FROM(QData),#FIELDS({campos}),#ORDINAL(1)
          BUTTON('&Salir'),AT(540,2,52,14),USE(?EvoExit),#ORDINAL(2)
        END
[END]
"""
salida.write_bytes(txa.replace("\n", "\r\n").encode("cp1252"))
print("ok", salida)
