/* ============================================================================
 *  tcwmss.c - motor de TCWMsSQL: SQL Server directo con la API de ODBC
 *  (odbc32.dll + "ODBC Driver 17/18 for SQL Server"), sin driver de Clarion ni
 *  tabla de trabajo. Lo compila Clarion dentro del exe: PRAGMA('compile(tcwmss.c)').
 *
 *  odbc32.dll se enlaza en runtime (LoadLibrary/GetProcAddress): Clarion no
 *  linkea los .lib de MSVC y no hay DLL propia para distribuir.
 *
 *  Cada consulta se lee ENTERA al ejecutarla (como mysql_store_result): las
 *  filas quedan en memoria y RowCount() es exacto. La lectura va por bloques
 *  (SQL_ATTR_ROW_ARRAY_SIZE). Si alguna columna es larga (varchar(max), text,
 *  xml, varbinary(max)) se lee fila por fila con SQLGetData, sin cortar nada.
 *  Todo viaja como texto (SQL_C_CHAR): fechas 'aaaa-mm-dd', decimales con punto.
 *
 *  Resultado en memoria: un bloque contiguo; cada fila = cols * long (largo,
 *  -1 = NULL) seguido de los valores sin separador. rowoff[i] = inicio de la fila.
 *
 *  Las funciones tms_* usan la convencion de Clarion (sin PASCAL en el MAP); las
 *  de odbc32 son WINAPI == Clacpp 'pascal' == __stdcall. Win32 (32-bit).
 * ========================================================================== */

#define WINAPI pascal

typedef void*          HANDLE;
typedef void*          HMODULE;
typedef short          SQLRETURN;
typedef int (WINAPI *FARPROC)();

#define SQL_HANDLE_ENV            1
#define SQL_HANDLE_DBC            2
#define SQL_HANDLE_STMT           3
#define SQL_ATTR_ODBC_VERSION     200
#define SQL_OV_ODBC3              3
#define SQL_ATTR_LOGIN_TIMEOUT    103
#define SQL_ATTR_AUTOCOMMIT       102
#define SQL_DRIVER_NOPROMPT       0
#define SQL_NTS                   (-3)
#define SQL_C_CHAR                1
#define SQL_VARCHAR               12
#define SQL_PARAM_INPUT           1
#define SQL_ATTR_ROW_BIND_TYPE    5
#define SQL_ATTR_ROWS_FETCHED_PTR 26
#define SQL_ATTR_ROW_ARRAY_SIZE   27
#define SQL_ATTR_PARAM_BIND_TYPE  18
#define SQL_ATTR_PARAMSET_SIZE    22
#define SQL_CLOSE                 0
#define SQL_RESET_PARAMS          3
#define SQL_NULL_DATA             (-1)
#define SQL_NO_TOTAL              (-4)
#define SQL_NO_DATA               100
#define SQL_COMMIT                0
#define SQL_ROLLBACK              1
#define SQL_OK(r)                 (((r) & ~1) == 0)     /* SUCCESS o SUCCESS_WITH_INFO */
#define MAX_COLS                  1024
#define MAX_WIDTH                 8000                  /* mas que esto = columna larga: SQLGetData */
#define BLOCK                     500
#define LPTR                      0x40

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
HANDLE  WINAPI LocalAlloc(unsigned int, unsigned long);
HANDLE  WINAPI LocalFree(HANDLE);

typedef SQLRETURN (WINAPI *PFN_AllocHandle)(short, HANDLE, HANDLE*);
typedef SQLRETURN (WINAPI *PFN_FreeHandle)(short, HANDLE);
typedef SQLRETURN (WINAPI *PFN_SetEnvAttr)(HANDLE, long, HANDLE, long);
typedef SQLRETURN (WINAPI *PFN_SetConnectAttr)(HANDLE, long, HANDLE, long);
typedef SQLRETURN (WINAPI *PFN_DriverConnect)(HANDLE, HANDLE, char*, short, char*, short, short*, unsigned short);
typedef SQLRETURN (WINAPI *PFN_Disconnect)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_ExecDirect)(HANDLE, char*, long);
typedef SQLRETURN (WINAPI *PFN_Prepare)(HANDLE, char*, long);
typedef SQLRETURN (WINAPI *PFN_Execute)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_NumResultCols)(HANDLE, short*);
typedef SQLRETURN (WINAPI *PFN_DescribeCol)(HANDLE, unsigned short, char*, short, short*, short*, unsigned long*, short*, short*);
typedef SQLRETURN (WINAPI *PFN_SetStmtAttr)(HANDLE, long, HANDLE, long);
typedef SQLRETURN (WINAPI *PFN_BindCol)(HANDLE, unsigned short, short, HANDLE, long, long*);
typedef SQLRETURN (WINAPI *PFN_BindParameter)(HANDLE, unsigned short, short, short, short, unsigned long, short, HANDLE, long, long*);
typedef SQLRETURN (WINAPI *PFN_Fetch)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_GetData)(HANDLE, unsigned short, short, HANDLE, long, long*);
typedef SQLRETURN (WINAPI *PFN_MoreResults)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_RowCount)(HANDLE, long*);
typedef SQLRETURN (WINAPI *PFN_FreeStmt)(HANDLE, unsigned short);
typedef SQLRETURN (WINAPI *PFN_EndTran)(short, HANDLE, short);
typedef SQLRETURN (WINAPI *PFN_GetInfo)(HANDLE, unsigned short, HANDLE, short, short*);
typedef SQLRETURN (WINAPI *PFN_Cancel)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_GetDiagRec)(short, HANDLE, short, char*, long*, char*, short, short*);

static PFN_AllocHandle    p_AllocHandle;
static PFN_FreeHandle     p_FreeHandle;
static PFN_SetEnvAttr     p_SetEnvAttr;
static PFN_SetConnectAttr p_SetConnectAttr;
static PFN_DriverConnect  p_DriverConnect;
static PFN_Disconnect     p_Disconnect;
static PFN_ExecDirect     p_ExecDirect;
static PFN_Prepare        p_Prepare;
static PFN_Execute        p_Execute;
static PFN_NumResultCols  p_NumResultCols;
static PFN_DescribeCol    p_DescribeCol;
static PFN_SetStmtAttr    p_SetStmtAttr;
static PFN_BindCol        p_BindCol;
static PFN_BindParameter  p_BindParameter;
static PFN_Fetch          p_Fetch;
static PFN_GetData        p_GetData;
static PFN_MoreResults    p_MoreResults;
static PFN_RowCount       p_RowCount;
static PFN_FreeStmt       p_FreeStmt;
static PFN_EndTran        p_EndTran;
static PFN_GetInfo        p_GetInfo;
static PFN_Cancel         p_Cancel;
static PFN_GetDiagRec     p_GetDiagRec;
static HANDLE             g_env = 0;

/* un resultado: la sentencia (para NextResult) y las filas en memoria */
typedef struct {
    HANDLE   stmt;
    long     cols;
    long     rows;
    long     cur;                  /* fila actual 1..rows (0 = antes de la primera) */
    long     affected;             /* filas afectadas (INSERT/UPDATE/DELETE) */
    char*    names;                /* nombres de columna, cada uno terminado en 0 */
    long*    nameoff;
    char*    data;
    long     used, cap;
    long*    rowoff;
    long     rowcap;
    long*    curoff;               /* desplazamiento de cada valor en la fila actual */
} TmsResult;

static void tms_copy(char* dst, const char* src, long n) { while (n-- > 0) *dst++ = *src++; }
static long tms_len(const char* s) { long n = 0; while (s[n]) n++; return n; }

static void tms_seterr(char* err, long errlen, char* state, const char* txt, const char* st) {
    long i = 0;
    if (err && errlen > 0) { while (txt[i] && i < errlen - 1) { err[i] = txt[i]; i++; } err[i] = 0; }
    if (state) { for (i = 0; i < 5; i++) state[i] = st[i]; state[5] = 0; }
}

/* texto del error de ODBC (todos los registros de diagnostico) y el SQLSTATE del primero */
static void tms_diag(short type, HANDLE h, char* err, long errlen, char* state, long* native) {
    char st[6], msg[1024];
    long nat, pos = 0, i;
    short len, rec;
    if (err && errlen > 0) err[0] = 0;
    if (state) state[0] = 0;
    if (native) *native = 0;
    for (rec = 1; rec <= 5; rec++) {
        if (!SQL_OK(p_GetDiagRec(type, h, rec, st, &nat, msg, sizeof(msg), &len))) break;
        if (rec == 1) {
            if (state) { for (i = 0; i < 6; i++) state[i] = st[i]; }
            if (native) *native = nat;
        }
        if (!err || errlen <= 0) continue;
        if (pos && pos < errlen - 3) { err[pos++] = ' '; err[pos++] = '|'; err[pos++] = ' '; }
        /* saca los prefijos [Microsoft][ODBC Driver 17 for SQL Server][SQL Server] */
        i = 0;
        while (msg[i] == '[') { while (msg[i] && msg[i] != ']') i++; if (msg[i]) i++; }
        for (; msg[i] && pos < errlen - 1; i++) err[pos++] = msg[i];
        err[pos] = 0;
    }
}

static int tms_init(char* err, long errlen, char* state) {
    HMODULE h;
    if (g_env) return 1;
    h = LoadLibraryA("odbc32.dll");
    if (!h) { tms_seterr(err, errlen, state, "No se pudo cargar odbc32.dll", "IM000"); return 0; }
    p_AllocHandle    = (PFN_AllocHandle)   GetProcAddress(h, "SQLAllocHandle");
    p_FreeHandle     = (PFN_FreeHandle)    GetProcAddress(h, "SQLFreeHandle");
    p_SetEnvAttr     = (PFN_SetEnvAttr)    GetProcAddress(h, "SQLSetEnvAttr");
    p_SetConnectAttr = (PFN_SetConnectAttr)GetProcAddress(h, "SQLSetConnectAttrA");
    p_DriverConnect  = (PFN_DriverConnect) GetProcAddress(h, "SQLDriverConnectA");
    p_Disconnect     = (PFN_Disconnect)    GetProcAddress(h, "SQLDisconnect");
    p_ExecDirect     = (PFN_ExecDirect)    GetProcAddress(h, "SQLExecDirectA");
    p_Prepare        = (PFN_Prepare)       GetProcAddress(h, "SQLPrepareA");
    p_Execute        = (PFN_Execute)       GetProcAddress(h, "SQLExecute");
    p_NumResultCols  = (PFN_NumResultCols) GetProcAddress(h, "SQLNumResultCols");
    p_DescribeCol    = (PFN_DescribeCol)   GetProcAddress(h, "SQLDescribeColA");
    p_SetStmtAttr    = (PFN_SetStmtAttr)   GetProcAddress(h, "SQLSetStmtAttr");
    p_BindCol        = (PFN_BindCol)       GetProcAddress(h, "SQLBindCol");
    p_BindParameter  = (PFN_BindParameter) GetProcAddress(h, "SQLBindParameter");
    p_Fetch          = (PFN_Fetch)         GetProcAddress(h, "SQLFetch");
    p_GetData        = (PFN_GetData)       GetProcAddress(h, "SQLGetData");
    p_MoreResults    = (PFN_MoreResults)   GetProcAddress(h, "SQLMoreResults");
    p_RowCount       = (PFN_RowCount)      GetProcAddress(h, "SQLRowCount");
    p_FreeStmt       = (PFN_FreeStmt)      GetProcAddress(h, "SQLFreeStmt");
    p_EndTran        = (PFN_EndTran)       GetProcAddress(h, "SQLEndTran");
    p_GetInfo        = (PFN_GetInfo)       GetProcAddress(h, "SQLGetInfoA");
    p_Cancel         = (PFN_Cancel)        GetProcAddress(h, "SQLCancel");
    p_GetDiagRec     = (PFN_GetDiagRec)    GetProcAddress(h, "SQLGetDiagRecA");
    if (!p_AllocHandle || !p_FreeHandle || !p_SetEnvAttr || !p_SetConnectAttr || !p_DriverConnect || !p_Disconnect ||
        !p_ExecDirect || !p_Prepare || !p_Execute || !p_NumResultCols || !p_DescribeCol || !p_SetStmtAttr || !p_BindCol || !p_BindParameter ||
        !p_Fetch || !p_GetData || !p_MoreResults || !p_RowCount || !p_FreeStmt || !p_EndTran || !p_GetInfo ||
        !p_Cancel || !p_GetDiagRec) {
        tms_seterr(err, errlen, state, "odbc32.dll sin las funciones esperadas", "IM000");
        return 0;
    }
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_ENV, 0, &g_env))) { g_env = 0; tms_seterr(err, errlen, state, "SQLAllocHandle(ENV) fallo", "IM000"); return 0; }
    p_SetEnvAttr(g_env, SQL_ATTR_ODBC_VERSION, (HANDLE)SQL_OV_ODBC3, 0);
    return 1;
}

/* ---------------------------------------------------------------- conexion */

/* conn = cadena ODBC completa ('Driver={...};Server=...;...'); timeout en segundos (0 = el del driver) */
long tms_connect(char* conn, long timeout, char* err, long errlen, char* state) {
    HANDLE dbc = 0;
    char out[1024];
    short outlen;
    if (!tms_init(err, errlen, state)) return 0;
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_DBC, g_env, &dbc))) { tms_seterr(err, errlen, state, "SQLAllocHandle(DBC) fallo", "HY001"); return 0; }
    if (timeout > 0) p_SetConnectAttr(dbc, SQL_ATTR_LOGIN_TIMEOUT, (HANDLE)timeout, 0);
    if (!SQL_OK(p_DriverConnect(dbc, 0, conn, SQL_NTS, out, sizeof(out), &outlen, SQL_DRIVER_NOPROMPT))) {
        tms_diag(SQL_HANDLE_DBC, dbc, err, errlen, state, 0);
        p_FreeHandle(SQL_HANDLE_DBC, dbc);
        return 0;
    }
    return (long)dbc;
}

void tms_disconnect(long dbc) {
    if (!dbc) return;
    p_Disconnect((HANDLE)dbc);
    p_FreeHandle(SQL_HANDLE_DBC, (HANDLE)dbc);
}

/* transacciones con la API: on=0 apaga el autocommit (empieza), tms_endtran confirma o deshace y lo vuelve a prender */
long tms_autocommit(long dbc, long on, char* err, long errlen, char* state) {
    if (!SQL_OK(p_SetConnectAttr((HANDLE)dbc, SQL_ATTR_AUTOCOMMIT, (HANDLE)(on ? 1 : 0), 0))) {
        tms_diag(SQL_HANDLE_DBC, (HANDLE)dbc, err, errlen, state, 0);
        return 0;
    }
    return 1;
}

long tms_endtran(long dbc, long commit, char* err, long errlen, char* state) {
    long ok = 1;
    if (!SQL_OK(p_EndTran(SQL_HANDLE_DBC, (HANDLE)dbc, (short)(commit ? SQL_COMMIT : SQL_ROLLBACK)))) {
        tms_diag(SQL_HANDLE_DBC, (HANDLE)dbc, err, errlen, state, 0);
        ok = 0;
    }
    p_SetConnectAttr((HANDLE)dbc, SQL_ATTR_AUTOCOMMIT, (HANDLE)1, 0);
    return ok;
}

/* SQLGetInfo como texto (6 = nombre del driver, 7 = version del driver, 17 = nombre del servidor de base) */
long tms_getinfo(long dbc, long what, char* out, long outlen) {
    short len = 0;
    out[0] = 0;
    if (!dbc || !SQL_OK(p_GetInfo((HANDLE)dbc, (unsigned short)what, out, (short)outlen, &len))) return 0;
    return len;
}

/* ---------------------------------------------------------------- resultado en memoria */

static int tms_reserve(TmsResult* r, long more) {
    char* nd;
    long ncap;
    if (r->used + more <= r->cap) return 1;
    ncap = r->cap ? r->cap * 2 : 65536;
    while (ncap < r->used + more) ncap *= 2;
    nd = (char*)LocalAlloc(0, (unsigned long)ncap);
    if (!nd) return 0;
    if (r->data) { tms_copy(nd, r->data, r->used); LocalFree(r->data); }
    r->data = nd;
    r->cap = ncap;
    return 1;
}

static int tms_addrow(TmsResult* r) {
    long* no;
    long ncap;
    if (r->rows >= r->rowcap) {
        ncap = r->rowcap ? r->rowcap * 2 : 1024;
        no = (long*)LocalAlloc(0, (unsigned long)(ncap * sizeof(long)));
        if (!no) return 0;
        if (r->rowoff) { tms_copy((char*)no, (char*)r->rowoff, r->rows * sizeof(long)); LocalFree(r->rowoff); }
        r->rowoff = no;
        r->rowcap = ncap;
    }
    if (!tms_reserve(r, r->cols * sizeof(long))) return 0;
    r->rowoff[r->rows++] = r->used;
    r->used += r->cols * sizeof(long);
    return 1;
}

/* agrega un valor a la ultima fila (c = 0..cols-1; len -1 = NULL) */
static int tms_addval(TmsResult* r, long c, const char* v, long len) {
    long* lens = (long*)(r->data + r->rowoff[r->rows - 1]);
    if (len > 0 && !tms_reserve(r, len)) return 0;
    lens = (long*)(r->data + r->rowoff[r->rows - 1]);          /* data pudo moverse */
    lens[c] = len;
    if (len > 0) { tms_copy(r->data + r->used, v, len); r->used += len; }
    return 1;
}

static void tms_clearrows(TmsResult* r) {
    if (r->data) LocalFree(r->data);
    if (r->rowoff) LocalFree(r->rowoff);
    if (r->names) LocalFree(r->names);
    if (r->nameoff) LocalFree(r->nameoff);
    if (r->curoff) LocalFree(r->curoff);
    r->data = 0; r->rowoff = 0; r->names = 0; r->nameoff = 0; r->curoff = 0;
    r->used = r->cap = r->rowcap = r->rows = r->cur = r->cols = 0;
}

/* lee el resultado actual entero: por bloques, o con SQLGetData si hay columnas largas */
static int tms_store(TmsResult* r, short cols, char* err, long errlen, char* state) {
    short namelen, type, dec, nullable;
    unsigned long size;
    char name[256];
    long c, i, n, w, lob = 0, namepos = 0, fetched = 0, block, got;
    long width[MAX_COLS];
    char* buf[MAX_COLS];
    long* ind[MAX_COLS];
    char* big = 0;
    long bigcap = 0;
    SQLRETURN rc;
    int ok = 0;

    if (cols > MAX_COLS) { tms_seterr(err, errlen, state, "Demasiadas columnas en el resultado", "HY000"); return 0; }
    r->cols = cols;
    r->names = (char*)LocalAlloc(LPTR, (unsigned long)(cols * 129));
    r->nameoff = (long*)LocalAlloc(LPTR, (unsigned long)(cols * sizeof(long)));
    r->curoff = (long*)LocalAlloc(LPTR, (unsigned long)(cols * sizeof(long)));
    if (!r->names || !r->nameoff || !r->curoff) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); return 0; }
    for (c = 0; c < cols; c++) {
        size = 0;
        name[0] = 0;
        p_DescribeCol(r->stmt, (unsigned short)(c + 1), name, sizeof(name), &namelen, &type, &size, &dec, &nullable);
        if (namelen > 128) namelen = 128;
        r->nameoff[c] = namepos;
        tms_copy(r->names + namepos, name, namelen);
        r->names[namepos + namelen] = 0;
        namepos += namelen + 1;
        /* texto: el largo declarado; numeros, fechas y binarios: espacio para su forma de texto */
        if (type == 1 || type == 12 || type == -1 || type == -8 || type == -9 || type == -10)
            w = (long)size;
        else if (type == -2 || type == -3 || type == -4)
            w = (long)size * 2;                                     /* binario -> hexadecimal */
        else
            w = (long)size + 3 < 48 ? 48 : (long)size + 3;
        if (size == 0 || w > MAX_WIDTH) lob = 1;
        width[c] = w + 1;
        buf[c] = 0;
        ind[c] = 0;
    }
    block = lob ? 1 : BLOCK;
    if (!lob) {
        p_SetStmtAttr(r->stmt, SQL_ATTR_ROW_BIND_TYPE, 0, 0);
        p_SetStmtAttr(r->stmt, SQL_ATTR_ROW_ARRAY_SIZE, (HANDLE)block, 0);
        p_SetStmtAttr(r->stmt, SQL_ATTR_ROWS_FETCHED_PTR, &fetched, 0);
        for (c = 0; c < cols; c++) {
            buf[c] = (char*)LocalAlloc(0, (unsigned long)(block * width[c]));
            ind[c] = (long*)LocalAlloc(0, (unsigned long)(block * sizeof(long)));
            if (!buf[c] || !ind[c]) { tms_seterr(err, errlen, state, "Sin memoria para el bloque", "HY001"); goto fin; }
            p_BindCol(r->stmt, (unsigned short)(c + 1), SQL_C_CHAR, buf[c], width[c], ind[c]);
        }
    } else {
        p_SetStmtAttr(r->stmt, SQL_ATTR_ROW_ARRAY_SIZE, (HANDLE)1, 0);
        bigcap = 65536;
        big = (char*)LocalAlloc(0, (unsigned long)bigcap);
        if (!big) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); goto fin; }
    }
    for (;;) {
        fetched = 0;
        rc = p_Fetch(r->stmt);
        if (rc == SQL_NO_DATA) break;
        if (!SQL_OK(rc)) { tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, 0); goto fin; }
        if (!lob) {
            for (i = 0; i < (long)fetched; i++) {
                if (!tms_addrow(r)) { tms_seterr(err, errlen, state, "Sin memoria para el resultado", "HY001"); goto fin; }
                for (c = 0; c < cols; c++) {
                    n = ind[c][i];
                    if (n != SQL_NULL_DATA && n > width[c] - 1) n = width[c] - 1;
                    if (!tms_addval(r, c, buf[c] + i * width[c], n == SQL_NULL_DATA ? -1 : n)) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); goto fin; }
                }
            }
        } else {
            if (!tms_addrow(r)) { tms_seterr(err, errlen, state, "Sin memoria para el resultado", "HY001"); goto fin; }
            for (c = 0; c < cols; c++) {
                /* SQLGetData por partes hasta SQL_NO_DATA: arma el valor entero en 'big' */
                got = 0;
                n = 0;
                for (;;) {
                    if (bigcap - got < 4097) {
                        char* nb = (char*)LocalAlloc(0, (unsigned long)(bigcap * 2));
                        if (!nb) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); goto fin; }
                        tms_copy(nb, big, got); LocalFree(big); big = nb; bigcap *= 2;
                    }
                    rc = p_GetData(r->stmt, (unsigned short)(c + 1), SQL_C_CHAR, big + got, bigcap - got, &n);
                    if (rc == SQL_NO_DATA) break;
                    if (!SQL_OK(rc)) { tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, 0); goto fin; }
                    if (n == SQL_NULL_DATA) break;
                    if (rc == 0) { got += n; break; }                              /* ultima parte */
                    got += tms_len(big + got);                                     /* parte llena (sin el 0 final) */
                }
                if (!tms_addval(r, c, big, n == SQL_NULL_DATA ? -1 : got)) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); goto fin; }
            }
        }
    }
    ok = 1;
fin:
    if (!lob) {
        p_FreeStmt(r->stmt, 2);                                     /* SQL_UNBIND */
        p_SetStmtAttr(r->stmt, SQL_ATTR_ROWS_FETCHED_PTR, 0, 0);
    }
    for (c = 0; c < cols; c++) { if (buf[c]) LocalFree(buf[c]); if (ind[c]) LocalFree(ind[c]); }
    if (big) LocalFree(big);
    return ok;
}

/* avanza hasta el proximo resultado con columnas (saltea los conteos de INSERT/UPDATE de un procedimiento).
   devuelve 1 = hay resultado, 0 = no hay mas, -1 = error */
static long tms_advance(TmsResult* r, int first, char* err, long errlen, char* state) {
    short cols;
    long cnt;
    SQLRETURN rc;
    for (;;) {
        if (!first) {
            rc = p_MoreResults(r->stmt);
            if (rc == SQL_NO_DATA) return 0;
            if (!SQL_OK(rc)) { tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, 0); return -1; }
        }
        first = 0;
        cols = 0;
        p_NumResultCols(r->stmt, &cols);
        if (cols > 0) return tms_store(r, cols, err, errlen, state) ? 1 : -1;
        cnt = -1;
        if (SQL_OK(p_RowCount(r->stmt, &cnt)) && cnt >= 0) r->affected += cnt;
    }
}

/* ejecuta sql con nparams parametros '?' (params = por cada uno: long largo (-1 = NULL) + los bytes) y lee el
   primer resultado. Devuelve el resultado (aunque no tenga columnas) o 0 si fallo (err, state, native). */
long tms_query(long dbc, char* sql, long nparams, char* params, char* err, long errlen, char* state, long* native) {
    TmsResult* r;
    SQLRETURN rc;
    long i, pos = 0, len;
    long* plen = 0;
    if (native) *native = 0;
    r = (TmsResult*)LocalAlloc(LPTR, sizeof(TmsResult));
    if (!r) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); return 0; }
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_STMT, (HANDLE)dbc, &r->stmt))) {
        tms_diag(SQL_HANDLE_DBC, (HANDLE)dbc, err, errlen, state, native);
        LocalFree(r);
        return 0;
    }
    if (nparams > 0) {
        plen = (long*)LocalAlloc(LPTR, (unsigned long)(nparams * sizeof(long)));
        if (!plen) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); p_FreeHandle(SQL_HANDLE_STMT, r->stmt); LocalFree(r); return 0; }
        for (i = 0; i < nparams; i++) {
            len = *(long*)(params + pos);
            pos += sizeof(long);
            plen[i] = len < 0 ? SQL_NULL_DATA : len;
            p_BindParameter(r->stmt, (unsigned short)(i + 1), SQL_PARAM_INPUT, SQL_C_CHAR,
                            (short)(len > 8000 ? -1 : SQL_VARCHAR),             /* mas de 8000: varchar(max) */
                            (unsigned long)(len > 0 ? len : 1), 0, params + pos, len > 0 ? len : 0, &plen[i]);
            if (len > 0) pos += len;
        }
    }
    rc = p_ExecDirect(r->stmt, sql, SQL_NTS);
    if (!SQL_OK(rc) && rc != SQL_NO_DATA) {
        tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, native);
        p_FreeHandle(SQL_HANDLE_STMT, r->stmt);
        LocalFree(r);
        if (plen) LocalFree(plen);
        return 0;
    }
    if (tms_advance(r, 1, err, errlen, state) < 0) {
        p_FreeHandle(SQL_HANDLE_STMT, r->stmt);
        tms_clearrows(r);
        LocalFree(r);
        if (plen) LocalFree(plen);
        return 0;
    }
    if (plen) LocalFree(plen);                                      /* los parametros ya se mandaron */
    return (long)r;
}

/* ---------------------------------------------------------------- sentencias preparadas */

/* prepara sql (con '?') una vez; se ejecuta las veces que haga falta con tms_execute. Devuelve el resultado o 0. */
long tms_prepare(long dbc, char* sql, char* err, long errlen, char* state, long* native) {
    TmsResult* r;
    if (native) *native = 0;
    r = (TmsResult*)LocalAlloc(LPTR, sizeof(TmsResult));
    if (!r) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); return 0; }
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_STMT, (HANDLE)dbc, &r->stmt))) {
        tms_diag(SQL_HANDLE_DBC, (HANDLE)dbc, err, errlen, state, native);
        LocalFree(r);
        return 0;
    }
    if (!SQL_OK(p_Prepare(r->stmt, sql, SQL_NTS))) {
        tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, native);
        p_FreeHandle(SQL_HANDLE_STMT, r->stmt);
        LocalFree(r);
        return 0;
    }
    return (long)r;
}

/* ejecuta la sentencia preparada con nrows filas de nparams parametros cada una, en UN solo viaje (arreglos de
   parametros de ODBC, enlazados por columna). params = fila por fila, por cada valor: long largo (-1 = NULL) + bytes.
   Devuelve 1 = bien, 0 = error (err, state, native); las filas afectadas quedan en tms_affected. */
long tms_execute(long h, long nrows, long nparams, char* params, char* err, long errlen, char* state, long* native) {
    TmsResult* r = (TmsResult*)h;
    SQLRETURN rc;
    long i, k, pos, len, w, ok = 0;
    long* width = 0;
    char** pbuf = 0;
    long** pind = 0;
    if (native) *native = 0;
    if (!r || !r->stmt) { tms_seterr(err, errlen, state, "No hay sentencia preparada", "HY010"); return 0; }
    if (nrows < 1) nrows = 1;
    p_FreeStmt(r->stmt, SQL_CLOSE);
    p_FreeStmt(r->stmt, SQL_RESET_PARAMS);
    tms_clearrows(r);
    r->affected = 0;
    if (nparams > 0) {
        width = (long*)LocalAlloc(LPTR, (unsigned long)(nparams * sizeof(long)));
        pbuf = (char**)LocalAlloc(LPTR, (unsigned long)(nparams * sizeof(char*)));
        pind = (long**)LocalAlloc(LPTR, (unsigned long)(nparams * sizeof(long*)));
        if (!width || !pbuf || !pind) { tms_seterr(err, errlen, state, "Sin memoria", "HY001"); goto fin; }
        /* 1ra pasada: el largo maximo de cada parametro (ancho de su columna en el arreglo) */
        pos = 0;
        for (i = 0; i < nrows; i++)
            for (k = 0; k < nparams; k++) {
                len = *(long*)(params + pos);
                pos += sizeof(long);
                if (len > width[k]) width[k] = len;
                if (len > 0) pos += len;
            }
        for (k = 0; k < nparams; k++) {
            if (width[k] < 1) width[k] = 1;
            pbuf[k] = (char*)LocalAlloc(0, (unsigned long)(nrows * width[k]));
            pind[k] = (long*)LocalAlloc(0, (unsigned long)(nrows * sizeof(long)));
            if (!pbuf[k] || !pind[k]) { tms_seterr(err, errlen, state, "Sin memoria para los parametros", "HY001"); goto fin; }
        }
        /* 2da pasada: copia cada valor a su columna */
        pos = 0;
        for (i = 0; i < nrows; i++)
            for (k = 0; k < nparams; k++) {
                len = *(long*)(params + pos);
                pos += sizeof(long);
                pind[k][i] = len < 0 ? SQL_NULL_DATA : len;
                if (len > 0) { tms_copy(pbuf[k] + i * width[k], params + pos, len); pos += len; }
            }
        p_SetStmtAttr(r->stmt, SQL_ATTR_PARAM_BIND_TYPE, 0, 0);    /* por columna */
        p_SetStmtAttr(r->stmt, SQL_ATTR_PARAMSET_SIZE, (HANDLE)nrows, 0);
        for (k = 0; k < nparams; k++) {
            w = width[k];
            p_BindParameter(r->stmt, (unsigned short)(k + 1), SQL_PARAM_INPUT, SQL_C_CHAR,
                            (short)(w > 8000 ? -1 : SQL_VARCHAR), (unsigned long)w, 0, pbuf[k], w, pind[k]);
        }
    }
    rc = p_Execute(r->stmt);
    if (!SQL_OK(rc) && rc != SQL_NO_DATA) { tms_diag(SQL_HANDLE_STMT, r->stmt, err, errlen, state, native); goto fin; }
    if (tms_advance(r, 1, err, errlen, state) < 0) goto fin;
    ok = 1;
fin:
    if (nparams > 0 && r) p_SetStmtAttr(r->stmt, SQL_ATTR_PARAMSET_SIZE, (HANDLE)1, 0);
    for (k = 0; k < nparams && pbuf; k++) { if (pbuf[k]) LocalFree(pbuf[k]); if (pind && pind[k]) LocalFree(pind[k]); }
    if (width) LocalFree(width);
    if (pbuf) LocalFree(pbuf);
    if (pind) LocalFree(pind);
    return ok;
}

/* pasa al resultado siguiente del mismo lote o procedimiento: 1 = hay, 0 = no hay mas, -1 = error */
long tms_nextresult(long h, char* err, long errlen, char* state) {
    TmsResult* r = (TmsResult*)h;
    if (!r || !r->stmt) return 0;
    tms_clearrows(r);
    return tms_advance(r, 0, err, errlen, state);
}

void tms_free(long h) {
    TmsResult* r = (TmsResult*)h;
    if (!r) return;
    if (r->stmt) p_FreeHandle(SQL_HANDLE_STMT, r->stmt);
    tms_clearrows(r);
    LocalFree(r);
}

long tms_cols(long h)     { return h ? ((TmsResult*)h)->cols : 0; }
long tms_rows(long h)     { return h ? ((TmsResult*)h)->rows : 0; }
long tms_affected(long h) { return h ? ((TmsResult*)h)->affected : 0; }

/* avanza a la fila siguiente: 1 = hay fila, 0 = fin */
long tms_next(long h) {
    TmsResult* r = (TmsResult*)h;
    long c, off, *lens;
    if (!r || r->cur >= r->rows) { if (r) r->cur = r->rows + 1; return 0; }
    r->cur++;
    lens = (long*)(r->data + r->rowoff[r->cur - 1]);
    off = r->rowoff[r->cur - 1] + r->cols * sizeof(long);
    for (c = 0; c < r->cols; c++) { r->curoff[c] = off; if (lens[c] > 0) off += lens[c]; }
    return 1;
}

/* largo del valor de la columna (1..cols) en la fila actual; -1 = NULL */
long tms_collen(long h, long col) {
    TmsResult* r = (TmsResult*)h;
    if (!r || r->cur < 1 || r->cur > r->rows || col < 1 || col > r->cols) return -1;
    return ((long*)(r->data + r->rowoff[r->cur - 1]))[col - 1];
}

/* direccion del valor (sin 0 final; el largo con tms_collen) */
long tms_colptr(long h, long col) {
    TmsResult* r = (TmsResult*)h;
    if (tms_collen(h, col) <= 0) return 0;
    return (long)(r->data + r->curoff[col - 1]);
}

long tms_colname(long h, long col, char* out, long outlen) {
    TmsResult* r = (TmsResult*)h;
    long n;
    out[0] = 0;
    if (!r || col < 1 || col > r->cols || !r->names) return 0;
    n = tms_len(r->names + r->nameoff[col - 1]);
    if (n > outlen - 1) n = outlen - 1;
    tms_copy(out, r->names + r->nameoff[col - 1], n);
    out[n] = 0;
    return n;
}

}  /* extern "C" */
