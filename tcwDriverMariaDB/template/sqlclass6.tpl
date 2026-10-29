#TEMPLATE (SqlClass, 'SqlClass para Clarion6'),FAMILY('ABC')
#SYSTEM
  #TAB('SQLClass')
  #BOXED('ODBC Override')
      #PROMPT('Enable ODBC Override',CHECK),%QDriverSetedOn,DEFAULT(%False)
      #PROMPT('Activates Translation',CHECK),%QTranslator,DEFAULT(%False)
      #DISPLAY('')
      #ENABLE(%QDriverSetedOn)
        #PROMPT('Replace ODBC Driver By:',DROP('ODBC|Informix|MsSQL|Oracle')),%QDriverSeted
        #DISPLAY('')
      #ENDENABLE
  #ENDBOXED
  #BOXED('Clases')
    #SHEET
      #TAB('ODBC')
        #PROMPT('Transaction:',FROM(%pClassName)),%ODBCTransClass,REQ,DEFAULT('ODBC_Trans')
      #ENDTAB
      #TAB('Informix')
        #PROMPT('Transaction:',FROM(%pClassName)),%InformixTransClass,REQ,DEFAULT('Ifx_Trans')
      #ENDTAB
      #TAB('MsSQL')
        #PROMPT('Transaction:',FROM(%pClassName)),%MsSQLTransClass,REQ,DEFAULT('MsSQL_Trans')
      #ENDTAB
      #TAB('Oracle')
        #PROMPT('Transaction:',FROM(%pClassName)),%OracleTransClass,REQ,DEFAULT('Ora_Trans')
      #ENDTAB
    #ENDSHEET
  #ENDBOXED
  #ENDTAB
#!õõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõ
#EXTENSION (SQLClass, 'Utilizacion de SQL class para Clarion6'), APPLICATION
#PREPARE
   #DECLARE(%SQLcontador,0)
   #FOR(%QTodosLosSQL)
       #SET(%SQLcontador,%SQLcontador+1)
   #ENDFOR
   #IF(%SQLcontador=0)
      #ADD(%QTodosLosSQL,'SQL')
      #SET(%QMiSQL,'SQL')
   #ENDIF
#ENDPREPARE
#SHEET
  #TAB('General')
      #DISPLAY
      #DISPLAY
      #BOXED(''),WHERE(%False),HIDE,AT(0,0,0,0)
      #PROMPT('Base de Datos :',DROP('ODBC|Informix|MsSQL|Oracle')),%QDriver,AT(0,0,0,0),PROMPTAT(0,0,0,0)
      #ENDBOXED
      #BOXED('Configuración')
        #PROMPT('Tomar Valor de Application Options',CHECK),%QDriverFromAppOpt,DEFAULT(0),AT(10)
        #ENABLE(NOT %QDriverFromAppOpt)
        #PROMPT('Base de Datos :',DROP('ODBC|Informix|MsSQL|Oracle')),%QDriverLocal
        #ENDENABLE
        #PROMPT('Nombre de Tabla SQL:',@s30),%QTablaSQL,DEFAULT('SQLClass'),REQ
        #PROMPT('Cant.Máxima de Campos:',@n3),%QMaxFields,DEFAULT(20),REQ
        #PROMPT('Tamaño Máximo de Campos:',@N3),%QFieldSize,DEFAULT(50),REQ
        #PROMPT('Usar StringTheory (log de la SQLClass)',CHECK),%QUsaStringTheory,DEFAULT(1),AT(10)
      #ENDBOXED
      #DISPLAY
      #BOXED('Opciones Run-Time')
        #PROMPT('Limitar Cant. Maxima de Registros',CHECK),%QMaxRegistros,AT(10)
        #ENABLE(%QMaxRegistros),CLEAR
        #PROMPT('Cant.Máx.Registros:',@n7),%QCantMaxRegistros,DEFAULT(500)
        #ENDENABLE
      #ENDBOXED
      #BUTTON ('Objetos SQL Globales'), MULTI(%QTodosLosSQL, %QMiSQL), INLINE
         #PROMPT('Nombre del Objeto SQL:',@s30),%QMiSQL,UNIQUE
         #PROMPT('Motor:',DROP('Driver de la app|MariaDB directo|SQL Server directo')),%QMiSQLMotor,DEFAULT('Driver de la app')
         #DISPLAY('MariaDB directo: SQLMariaClass (libmariadb.dll), mismo Init y mismos metodos.')
         #DISPLAY('SQL Server directo: SQLMsDirectClass (API ODBC + ODBC Driver 17/18), mismo Init.')
         #DISPLAY('Owner de siempre: servidor,base,usuario,clave')
         #PROMPT('Conexion:',EXPR),%QMiSQLConexion
         #DISPLAY('Variable o texto entre comillas. Con valor, el objeto se conecta solo al')
         #DISPLAY('iniciar el programa (despues del codigo de Program Setup). Vacio = Init a mano.')
      #ENDBUTTON
  #ENDTAB
#ENDSHEET
  #ATSTART
   #IF(%QDriverFromAppOpt)
       #IF(%QDriverSetedOn)
           #SET(%QDriver,%QDriverSeted)
       #END
   #ELSE
       #SET(%QDriver,%QDriverLocal)
   #ENDIF
   #DECLARE(%QParentSQL)
   #CASE(%QDriver)
    #OF('ODBC')
       #SET(%QParentSQL,'SQLOdbcClass')
    #OF('Informix')
       #SET(%QParentSQL,'SQLIfxClass')
    #OF('MsSQL')
       #SET(%QParentSQL,'SQLMsClass')
    #OF('Oracle')
       #SET(%QParentSQL,'SQLOraClass')
   #ENDCASE
   #DECLARE(%QParentDriver)
   #SET(%QParentDriver,%QParentSQL)
   #DECLARE(%QHayMaria)
   #SET(%QHayMaria,%False)
   #FOR(%QTodosLosSQL),WHERE(%QMiSQLMotor='MariaDB directo')
     #SET(%QHayMaria,%True)
   #ENDFOR
   #DECLARE(%QHayMsDirect)
   #SET(%QHayMsDirect,%False)
   #FOR(%QTodosLosSQL),WHERE(%QMiSQLMotor='SQL Server directo')
     #SET(%QHayMsDirect,%True)
   #ENDFOR
   #DECLARE (%QpClassMethod),UNIQUE,MULTI
   #DECLARE (%QpClassMethodPrototype,%QpClassMethod),UNIQUE,MULTI
   #DECLARE (%QpClassMethodPrototypeNames,%QpClassMethodPrototype)
   #DECLARE (%QpClassMethodElPrototype,%QpClassMethodPrototype)
   #DECLARE (%QpClassMethodIsVirtual,  %QpClassMethodPrototype)
   #DECLARE (%QpClassMethodReturnType,%QpClassMethodPrototype)
   #DECLARE (%QExportedObject)
   #DECLARE (%QValorAExportar)
   #DECLARE (%MiValor)
   #DECLARE (%QModuleL)
   #SET(%QModuleL,CLIP(LEFT(%Program,LEN(CLIP(%Program))-4)))
   #SET(%QModuleL,CLIP(LEFT(%QModuleL,5))&'SQL.CLW')
   #CALL(%GrupoDefinicion)
  #ENDAT

  #AT(%CustomGlobalDeclarations)
    #CASE(%QDriver)
      #OF('ODBC')
        #PROJECT('C60ODBX.LIB')
      #OF('Informix')
        #PROJECT('C60IFXX.LIB')
      #OF('MsSQL')
        #PROJECT('C60MSSX.LIB')
      #OF('Oracle')
        #PROJECT('C6055ORAX.LIB')
    #ENDCASE
    #IF(%QHayMaria)
      #PROJECT('libmariadb.lib')
    #ENDIF
    #IF(NOT %QUsaStringTheory)
      #PDEFINE('SQLClass6SinStringTheory',1)
    #ENDIF
  #ENDAT

  #!,WHERE(NOT %GlobalExternal)
  #AT(%BeforeGlobalIncludes)
   INCLUDE('SQLClass6.INC'),ONCE
   #IF(%QHayMaria)
   INCLUDE('SQLClass6Maria.inc'),ONCE
   #ENDIF
   #IF(%QHayMsDirect)
   INCLUDE('SQLClass6MsDirect.inc'),ONCE
   #ENDIF
  #ENDAT

  #AT(%GlobalData)
#INSERT(%GrupoGeneracionFile)
  #FOR(%QTodosLosSQL)
#INSERT(%GrupoParentInstancia)
#INSERT(%GrupoGeneracionSQLClass,%QMiSQL)
  #ENDFOR
#SET(%QParentSQL,%QParentDriver)
! **************** FIN Generacion SQL Class *****************************
  #ENDAT

#AT(%CustomGlobalDeclarations),WHERE(NOT %GlobalExternal)
  #PROJECT(%QModuleL)
#ENDAT
#AT (%GlobalMap),WHERE(NOT %GlobalExternal)
#INSERT(%GrupoGenerarModule)
MODULE('%'QModuleL')
SQLClass:DctInit    ()
END
#ENDAT

#AT(%DLLExportList),WHERE(NOT %GlobalExternal)
#INSERT(%GrupoDLLExportListFile)
#INSERT(%GrupoDLLExportListClass)
#ENDAT
#AT(%ProgramSetup),WHERE(NOT %GlobalExternal)
 SQLClass:DctInit
#ENDAT
#AT(%ProgramSetup),PRIORITY(9000),WHERE(NOT %GlobalExternal)
  #FOR(%QTodosLosSQL),WHERE(%QMiSQLConexion)
    #CASE(%QMiSQLMotor)
    #OF('MariaDB directo')
 IF %QMiSQL.InitMaria(%QMiSQLConexion) <> Level:Benign  ! SQLClass: conexion del template global (el error ya lo mostro la clase)
    #OF('SQL Server directo')
 IF %QMiSQL.InitDirect(%QMiSQLConexion) <> Level:Benign  ! SQLClass: conexion del template global (el error ya lo mostro la clase)
    #ELSE
 IF %QMiSQL.Init(%QTablaSQL,uSQL:Record,%QMiSQLConexion) <> Level:Benign  ! SQLClass: conexion del template global
    #ENDCASE
 END
  #ENDFOR
#ENDAT
! **************** SQL Class *****************************
#AT(%QSQLEmbedsCode,%QMiSQL,%QpClassMethod,%QpClassMethodPrototype),PRIORITY(5000),DESCRIPTION('Parent Call'),WHERE(NOT %GlobalExternal)
  #IF(%QpClassMethodReturnType)
ReturnValue = PARENT.%QpClassMethod%QpClassMethodPrototypeNames
  #ELSE
Parent.%QpClassMethod%QpClassMethodPrototypeNames
  #END
#ENDAT
#AT(%QSQLEmbedsCode,%QMiSQL,%QpClassMethod,%QpClassMethodPrototype),PRIORITY(9999),WHERE(%QpClassMethodReturnType),WHERE(NOT %GlobalExternal)
  #IF(%QpClassMethodReturnType)
RETURN ReturnValue
  #ELSE
RETURN
  #END
#ENDAT
#!****************************************************************
#GROUP(%GrupoMetodo,%QObjeto,%QMethodName,%QParametros,%QElParametros,%QParamNombres,%QEsVirtual='',%QRetorna)
#DECLARE(%pQParametros)
#DECLARE(%QHideObjeto)
#SET(%QHideObjeto,'Hide:'&%QObjeto)
Hide:%QObjeto.%QMethodName PROCEDURE%QElParametros
#IF(%QRetorna)
ReturnValue %QRetorna
#END
#IF(%QEsVirtual)
#EMBED(%QSQLEmbedsData,'Sqlclass_SQL Data Section'),%QObjeto,%QMethodName,%QParametros,LABEL,DATA,TREE('Global Objects|'&'Hide:'&%QObjeto&' ('&%QParentSQL&') Instancia Global de '&%QParentSQL&'|'&%QMethodName&' PROCEDURE'&%QParametros&'{{COLOR('&%ColorVirtualMethod&')}'&'|DATA{{COLOR('&%ColorDataSection&'),PRIORITY(5000)}')

  CODE

  #EMBED(%QSQLEmbedsCode,'Sqlclass_SQL Code Section'),%QObjeto,%QMethodName,%QParametros,TREE('Global Objects|'&'Hide:'&%QObjeto&' ('&%QParentSQL&') Instancia Global de '&%QParentSQL&'|'&%QMethodName&' PROCEDURE'&%QParametros&'{{COLOR('&%ColorVirtualMethod&')}'&'|CODE{{COLOR('&%ColorCodeSection&'),PRIORITY(5001)}')

#ELSE
#EMBED(%QSQLEmbedsData,'Sqlclass_SQL Data Section'),%QObjeto,%QMethodName,%QParametros,LABEL,DATA,TREE('Global Objects|'&'Hide:'&%QObjeto&' ('&%QParentSQL&') Instancia Global de '&%QParentSQL&'|'&%QMethodName&' PROCEDURE'&%QParametros&'|DATA{{COLOR('&%ColorDataSection&'),PRIORITY(5000)}')

  CODE

  #EMBED(%QSQLEmbedsCode,'Sqlclass_SQL Code Section'),%QObjeto,%QMethodName,%QParametros,TREE('Global Objects|'&'Hide:'&%QObjeto&' ('&%QParentSQL&') Instancia Global de '&%QParentSQL&'|'&%QMethodName&' PROCEDURE'&%QParametros&'|CODE{{COLOR('&%ColorCodeSection&'),PRIORITY(5001)}')

#ENDIF
#!****************************************************************
#GROUP(%GrupoParentInstancia)
#IF(%QMiSQLMotor='MariaDB directo')
  #SET(%QParentSQL,'SQLMariaClass')
#ELSIF(%QMiSQLMotor='SQL Server directo')
  #SET(%QParentSQL,'SQLMsDirectClass')
#ELSE
  #SET(%QParentSQL,%QParentDriver)
#ENDIF
#!****************************************************************
#GROUP(%GrupoGeneracionFile)
#DECLARE(%Contador)
! **************** Generacion SQL Class *****************************
 #IF(NOT %GlobalExternal)
%[21]QTablaSQL  FILE,DRIVER('%QDriver'),CREATE,NAME('%QTablaSQL'),PRE(uSQL)
 #ELSE
%[21]QTablaSQL  FILE,DRIVER('%QDriver'),CREATE,NAME('%QTablaSQL'),PRE(uSQL),EXTERNAL(''),DLL(dll_mode)
 #ENDIF
Record      RECORD,PRE()
#LOOP,FOR(%Contador,1,%QMaxFields)
f%Contador   CSTRING(%QFieldSize)
#ENDLOOP
            END
           END
#!****************************************************************
#GROUP(%GrupoGeneracionSQLClass,%QPSqlClass)
 #IF(NOT %GlobalExternal)
%[21]QPSqlClass        &%QParentSQL
 #ELSE
%[21]QPSqlClass        &%QParentSQL,EXTERNAL,DLL(dll_mode)
 #ENDIF
#!****************************************************************
#GROUP(%GrupoDeclaracionDeMetodos,%QClassMethod,%QClassMethodPrototype,%QClassMethodIsVirtual)
  #IF(%QClassMethodIsVirtual)
%[50]QClassMethod      PROCEDURE%QClassMethodPrototype,VIRTUAL
  #ELSE
%[50]QClassMethod      PROCEDURE%QClassMethodPrototype
  #END
#!****************************************************************
#GROUP(%GrupoDLLExportListFile)
  #SET(%QValorAExportar,UPPER('$'&%QTablaSQL))
  %[55]QValorAExportar @?
  #SET(%QValorAExportar,UPPER(%QTablaSQL&'$USQL:RECORD'))
  %[55]QValorAExportar @?
  #SET(%QValorAExportar,UPPER(%QTablaSQL&'$TYPE$USQL:RECORD'))
  %[55]QValorAExportar @?
#!****************************************************************
#GROUP(%GrupoDLLExportListClass)
    #FOR(%QTodosLosSQL)
    #SET(%QValorAExportar,'$'&UPPER(%QMiSQL))
  %[55]QValorAExportar @?
    #ENDFOR
#!****************************************************************
#GROUP(%GrupoCreaSimbolos,%QMethodName,%QParametros,%QParamNombres='',%QEsVirtual='',%QReturnType='')
 #IF(%QParamNombres='')
    #SET(%QParamNombres,%QParametros)
 #ENDIF
 #ADD(%QpClassMethod,%QMethodName)
 #IF(%QReturnType)
 #ADD(%QpClassMethodPrototype,%QParametros&','&%QReturnType)
 #ELSE
 #ADD(%QpClassMethodPrototype,%QParametros)
 #ENDIF
 #SET(%QpClassMethodElPrototype,%QParametros)
 #SET(%QpClassMethodPrototypeNames,%QParamNombres)
 #SET(%QpClassMethodIsVirtual,  %QEsVirtual)
 #SET(%QpClassMethodReturnType,%QReturnType)
 

#!****************************************************************
#GROUP(%GrupoGenerarModule)
#DECLARE(%QModule)
#SET(%QModule,CLIP(LEFT(%Program,LEN(CLIP(%Program))-4)))
#SET(%QModule,CLIP(LEFT(%QModule,5))&'SQL.CLW')
#MESSAGE('Generating Module:    '&%QModule,1)
#MESSAGE('Generating SQLClass Module',2)
#MESSAGE('',3)
#CREATE(%QModule)
  MEMBER('%'Program')

   INCLUDE('SQLClass6.INC')!,ONCE
#IF(%QHayMaria)
   INCLUDE('SQLClass6Maria.inc'),ONCE
#ENDIF
#IF(%QHayMsDirect)
   INCLUDE('SQLClass6MsDirect.inc'),ONCE
#ENDIF

#FOR(%QTodosLosSQL)
#INSERT(%GrupoParentInstancia)
Hide:%[21]QMiSQL CLASS(%QParentSQL) ! Declaracion (falta parametros del class)
#FOR(%QpClassMethod)
   #FOR(%QpClassMethodPrototype)
#INSERT(%GrupoDeclaracionDeMetodos,%QpClassMethod,%QpClassMethodPrototype,%QpClassMethodIsVirtual)
   #ENDFOR
#ENDFOR
        END!CLASS
#ENDFOR

SQLClass:DctInit PROCEDURE
  CODE
#FOR(%QTodosLosSQL)
  %QMiSQL &= Hide:%QMiSQL
#ENDFOR
#IF(%QMaxRegistros>0)
  #FOR(%QTodosLosSQL)
  %QMiSQL.MaxReads = %QCantMaxRegistros
  #ENDFOR
#ENDIF

#FOR(%QTodosLosSQL)
#INSERT(%GrupoParentInstancia)
 #FOR(%QpClassMethod)
    #FOR(%QpClassMethodPrototype)
#INSERT(%GrupoMetodo,%QMiSQL,%QpClassMethod,%QpClassMethodPrototype,%QpClassMethodElPrototype,%QpClassMethodPrototypeNames,%QpClassMethodIsVirtual,%QpClassMethodReturnType)

    #ENDFOR
 #ENDFOR
#ENDFOR


#SET(%QParentSQL,%QParentDriver)
#CLOSE(%QModule)
#!****************************************************************
#GROUP(%GrupoDefinicion)
  #INSERT(%GrupoCreaSimbolos,'Init','(*File Archivo,*Group Registro,String StrConexion)','(Archivo,Registro,StrConexion)','True','BYTE')
  #INSERT(%GrupoCreaSimbolos,'Kill','()',,,'')
  #INSERT(%GrupoCreaSimbolos,'Col_Format','(Short NroCol,String Formato)','(NroCol,Formato)',,'')
  #INSERT(%GrupoCreaSimbolos,'Exec','(String Query)','(Query)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Fetch','(Short NroCol,String Query)','(NroCol,Query)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Fetch','(Short NroCol,String Query,*String Result)','(NroCol,Query,Result)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'SP','(Short NoCols, String Query)','(NoCols,Query)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Parse','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Columns','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Field','(Short Col)','(Col)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'ServerExec','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Next','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'Records','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'RegisterUpdate','(*FileManager MyFm ,*Key MyKey,*? MyField)','(MyFm,MyKey,MyField)','True','')
  #INSERT(%GrupoCreaSimbolos,'UpdateBuffer','()',,,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'LoadQueue','(*Queue MyQ,Byte WithCount,Byte ShowWin)','(MyQ,WithCount,ShowWin)',,'BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeRecord','()',,'TRUE','BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeInsert','()',,'TRUE','BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeDelete','()',,'TRUE','BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeSelect','()',,'TRUE','BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeDrop'  ,'()',,'TRUE','BYTE')
  #INSERT(%GrupoCreaSimbolos,'TakeUpdate','()',,'TRUE','BYTE')
#!õõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõ
#CODE(SQLInit,'Initialize SQL Class Object')
  #SHEET
    #TAB('General')
      #DISPLAY
      #DISPLAY('Inicializa la SQL Class')
      #DISPLAY
      #PROMPT('SQL Mode :',EXPR),%SQLMode,REQ
      #PROMPT('Owner Name :',FIELD),%SQLOwnerName,REQ
      #DISPLAY
      #DISPLAY
      #PROMPT('Halt on Error',CHECK),%SQLRetOnError,REQ
    #ENDTAB
  #ENDSHEET
! SQL Templates (Code Template SQLInit). Version: %SQLVersion
#CASE(%SQLVersion)
   #OF('v3')
 #IF(%SQLMode)
 SQL.Mode = %SQLMode   
 #ELSE
 ! ** SQL.Mode not configured in template
 #ENDIF
 SQLError# = SQL.Init( SQL_View , %SQLOwnerName )
   #ELSE
 SQLError# = SQL.Init( SQLClass, SQLClass:record , %SQLOwnerName )
#ENDCASE
 #IF(%SQLRetOnError)
 IF SQLError#
    RETURN Level:Fatal
 END!IF
 #ELSE
 ! ** No Error Control Defined in template
 #ENDIF
 ! End SQLInit Code Template
#!õõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõõ
