/* ============================================================================
 *  tcwodbc.c - SQL Server (o cualquier origen ODBC) directo desde Clarion con
 *  la API de ODBC: sin driver de Clarion, sin tabla de trabajo, sin limite de
 *  columnas ni de largo. Prueba de velocidad de tcwDriverMSSQL.
 *
 *  odbc32.dll se enlaza en runtime (LoadLibrary/GetProcAddress): Clarion no
 *  linkea los .lib de MSVC. El driver real es el "ODBC Driver 17/18 for SQL
 *  Server" (msodbcsql), la biblioteca nativa de Microsoft que habla TDS.
 *
 *  Lectura por bloques: cada columna se enlaza como texto (SQL_C_CHAR) en un
 *  arreglo de N filas (SQL_ATTR_ROW_ARRAY_SIZE) y cada SQLFetch trae N filas.
 *  Con N = 1 se comporta como una lectura fila por fila.
 *
 *  Uso desde Clarion (ver BenchMSSQL.clw):
 *    hDbc = tco_connect(conexion, err, len)
 *    h    = tco_exec(hDbc, sql, bloque, err, len)
 *    LOOP: n = tco_fetch(h) ; fila 1..n: tco_get(h, fila, col, buf, len)
 *    tco_close(h) ; tco_disconnect(hDbc)
 *  Las funciones tco_* usan la convencion de Clarion (sin PASCAL en el MAP); las de
 *  odbc32 son WINAPI == Clacpp 'pascal' == __stdcall. Win32 (32-bit).
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
#define SQL_DRIVER_NOPROMPT       0
#define SQL_NTS                   (-3)
#define SQL_C_CHAR                1
#define SQL_ATTR_ROW_BIND_TYPE    5
#define SQL_ATTR_ROWS_FETCHED_PTR 26
#define SQL_ATTR_ROW_ARRAY_SIZE   27
#define SQL_NULL_DATA             (-1)
#define SQL_NO_DATA               100
#define SQL_OK(r)                 (((r) & ~1) == 0)     /* SUCCESS o SUCCESS_WITH_INFO */
#define MAX_COLS                  256
#define MAX_WIDTH                 8000

extern "C" {

HMODULE WINAPI LoadLibraryA(const char*);
FARPROC WINAPI GetProcAddress(HMODULE, const char*);
HANDLE  WINAPI LocalAlloc(unsigned int, unsigned long);
HANDLE  WINAPI LocalFree(HANDLE);

typedef SQLRETURN (WINAPI *PFN_AllocHandle)(short, HANDLE, HANDLE*);
typedef SQLRETURN (WINAPI *PFN_FreeHandle)(short, HANDLE);
typedef SQLRETURN (WINAPI *PFN_SetEnvAttr)(HANDLE, long, HANDLE, long);
typedef SQLRETURN (WINAPI *PFN_DriverConnect)(HANDLE, HANDLE, char*, short, char*, short, short*, unsigned short);
typedef SQLRETURN (WINAPI *PFN_Disconnect)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_ExecDirect)(HANDLE, char*, long);
typedef SQLRETURN (WINAPI *PFN_NumResultCols)(HANDLE, short*);
typedef SQLRETURN (WINAPI *PFN_DescribeCol)(HANDLE, unsigned short, char*, short, short*, short*, unsigned long*, short*, short*);
typedef SQLRETURN (WINAPI *PFN_SetStmtAttr)(HANDLE, long, HANDLE, long);
typedef SQLRETURN (WINAPI *PFN_BindCol)(HANDLE, unsigned short, short, HANDLE, long, long*);
typedef SQLRETURN (WINAPI *PFN_Fetch)(HANDLE);
typedef SQLRETURN (WINAPI *PFN_GetDiagRec)(short, HANDLE, short, char*, long*, char*, short, short*);

static PFN_AllocHandle   p_AllocHandle;
static PFN_FreeHandle    p_FreeHandle;
static PFN_SetEnvAttr    p_SetEnvAttr;
static PFN_DriverConnect p_DriverConnect;
static PFN_Disconnect    p_Disconnect;
static PFN_ExecDirect    p_ExecDirect;
static PFN_NumResultCols p_NumResultCols;
static PFN_DescribeCol   p_DescribeCol;
static PFN_SetStmtAttr   p_SetStmtAttr;
static PFN_BindCol       p_BindCol;
static PFN_Fetch         p_Fetch;
static PFN_GetDiagRec    p_GetDiagRec;
static HANDLE            g_env = 0;

/* un resultado abierto: columnas enlazadas como texto, N filas por bloque */
typedef struct {
    HANDLE        stmt;
    long          cols;
    long          block;
    unsigned long fetched;
    long          width[MAX_COLS];      /* largo de cada valor + 1 (el cero final) */
    char*         buf[MAX_COLS];        /* block * width[c] bytes */
    long*         ind[MAX_COLS];        /* largo o SQL_NULL_DATA por fila */
} TcoResult;

static void tco_copy(char* dst, const char* src, long n) { while (n-- > 0) *dst++ = *src++; }

static void tco_seterr(char* err, long errlen, const char* txt) {
    long i = 0;
    if (!err || errlen <= 0) return;
    while (txt[i] && i < errlen - 1) { err[i] = txt[i]; i++; }
    err[i] = 0;
}

/* texto del error de ODBC: [estado] mensaje (de todos los registros de diagnostico) */
static void tco_diag(short type, HANDLE h, char* err, long errlen) {
    char state[6], msg[1024];
    long native, pos = 0, i;
    short len, rec;
    if (!err || errlen <= 0) return;
    err[0] = 0;
    for (rec = 1; rec <= 4; rec++) {
        if (!SQL_OK(p_GetDiagRec(type, h, rec, state, &native, msg, sizeof(msg), &len))) break;
        if (pos && pos < errlen - 3) { err[pos++] = ' '; err[pos++] = '|'; err[pos++] = ' '; }
        for (i = 0; msg[i] && pos < errlen - 1; i++) err[pos++] = msg[i];
        err[pos] = 0;
    }
}

static int tco_init(char* err, long errlen) {
    HMODULE h;
    if (g_env) return 1;
    h = LoadLibraryA("odbc32.dll");
    if (!h) { tco_seterr(err, errlen, "No se pudo cargar odbc32.dll"); return 0; }
    p_AllocHandle   = (PFN_AllocHandle)  GetProcAddress(h, "SQLAllocHandle");
    p_FreeHandle    = (PFN_FreeHandle)   GetProcAddress(h, "SQLFreeHandle");
    p_SetEnvAttr    = (PFN_SetEnvAttr)   GetProcAddress(h, "SQLSetEnvAttr");
    p_DriverConnect = (PFN_DriverConnect)GetProcAddress(h, "SQLDriverConnectA");
    p_Disconnect    = (PFN_Disconnect)   GetProcAddress(h, "SQLDisconnect");
    p_ExecDirect    = (PFN_ExecDirect)   GetProcAddress(h, "SQLExecDirectA");
    p_NumResultCols = (PFN_NumResultCols)GetProcAddress(h, "SQLNumResultCols");
    p_DescribeCol   = (PFN_DescribeCol)  GetProcAddress(h, "SQLDescribeColA");
    p_SetStmtAttr   = (PFN_SetStmtAttr)  GetProcAddress(h, "SQLSetStmtAttr");
    p_BindCol       = (PFN_BindCol)      GetProcAddress(h, "SQLBindCol");
    p_Fetch         = (PFN_Fetch)        GetProcAddress(h, "SQLFetch");
    p_GetDiagRec    = (PFN_GetDiagRec)   GetProcAddress(h, "SQLGetDiagRecA");
    if (!p_AllocHandle || !p_FreeHandle || !p_SetEnvAttr || !p_DriverConnect || !p_Disconnect || !p_ExecDirect ||
        !p_NumResultCols || !p_DescribeCol || !p_SetStmtAttr || !p_BindCol || !p_Fetch || !p_GetDiagRec) {
        tco_seterr(err, errlen, "odbc32.dll sin las funciones esperadas");
        return 0;
    }
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_ENV, 0, &g_env))) { g_env = 0; tco_seterr(err, errlen, "SQLAllocHandle(ENV) fallo"); return 0; }
    p_SetEnvAttr(g_env, SQL_ATTR_ODBC_VERSION, (HANDLE)SQL_OV_ODBC3, 0);
    return 1;
}

/* conecta con una cadena ODBC: 'Driver={ODBC Driver 17 for SQL Server};Server=...;Database=...;Uid=...;Pwd=...' */
long tco_connect(char* conn, char* err, long errlen) {
    HANDLE dbc = 0;
    char out[1024];
    short outlen;
    if (!tco_init(err, errlen)) return 0;
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_DBC, g_env, &dbc))) { tco_seterr(err, errlen, "SQLAllocHandle(DBC) fallo"); return 0; }
    if (!SQL_OK(p_DriverConnect(dbc, 0, conn, SQL_NTS, out, sizeof(out), &outlen, SQL_DRIVER_NOPROMPT))) {
        tco_diag(SQL_HANDLE_DBC, dbc, err, errlen);
        p_FreeHandle(SQL_HANDLE_DBC, dbc);
        return 0;
    }
    return (long)dbc;
}

void tco_disconnect(long dbc) {
    if (!dbc) return;
    p_Disconnect((HANDLE)dbc);
    p_FreeHandle(SQL_HANDLE_DBC, (HANDLE)dbc);
}

void tco_close(long h) {
    TcoResult* r = (TcoResult*)h;
    long c;
    if (!r) return;
    if (r->stmt) p_FreeHandle(SQL_HANDLE_STMT, r->stmt);
    for (c = 0; c < r->cols; c++) {
        if (r->buf[c]) LocalFree(r->buf[c]);
        if (r->ind[c]) LocalFree(r->ind[c]);
    }
    LocalFree(r);
}

/* ejecuta y enlaza todas las columnas como texto en bloques de 'block' filas; devuelve el resultado o 0 */
long tco_exec(long dbc, char* sql, long block, char* err, long errlen) {
    TcoResult* r;
    short cols, namelen, type, dec, nullable;
    unsigned long size;
    char name[256];
    long c, w;
    if (block < 1) block = 1;
    r = (TcoResult*)LocalAlloc(0x40, sizeof(TcoResult));          /* LPTR: en cero */
    if (!r) { tco_seterr(err, errlen, "Sin memoria"); return 0; }
    r->block = block;
    if (!SQL_OK(p_AllocHandle(SQL_HANDLE_STMT, (HANDLE)dbc, &r->stmt))) {
        tco_diag(SQL_HANDLE_DBC, (HANDLE)dbc, err, errlen); r->stmt = 0; tco_close((long)r); return 0;
    }
    if (!SQL_OK(p_ExecDirect(r->stmt, sql, SQL_NTS))) { tco_diag(SQL_HANDLE_STMT, r->stmt, err, errlen); tco_close((long)r); return 0; }
    p_NumResultCols(r->stmt, &cols);
    if (cols > MAX_COLS) cols = MAX_COLS;
    r->cols = cols;
    if (cols <= 0) return (long)r;                                  /* sin resultado (INSERT, UPDATE...) */
    p_SetStmtAttr(r->stmt, SQL_ATTR_ROW_BIND_TYPE, 0, 0);           /* por columna */
    p_SetStmtAttr(r->stmt, SQL_ATTR_ROW_ARRAY_SIZE, (HANDLE)block, 0);
    p_SetStmtAttr(r->stmt, SQL_ATTR_ROWS_FETCHED_PTR, &r->fetched, 0);
    for (c = 0; c < cols; c++) {
        size = 0;
        p_DescribeCol(r->stmt, (unsigned short)(c + 1), name, sizeof(name), &namelen, &type, &size, &dec, &nullable);
        w = (size == 0 || size > MAX_WIDTH) ? MAX_WIDTH : (long)size + 3;   /* signo, punto decimal */
        r->width[c] = w + 1;
        r->buf[c] = (char*)LocalAlloc(0, (unsigned long)(block * r->width[c]));
        r->ind[c] = (long*)LocalAlloc(0, (unsigned long)(block * sizeof(long)));
        if (!r->buf[c] || !r->ind[c]) { tco_seterr(err, errlen, "Sin memoria para el bloque"); tco_close((long)r); return 0; }
        p_BindCol(r->stmt, (unsigned short)(c + 1), SQL_C_CHAR, r->buf[c], r->width[c], r->ind[c]);
    }
    return (long)r;
}

long tco_cols(long h) { return h ? ((TcoResult*)h)->cols : 0; }

/* trae el bloque siguiente: devuelve la cantidad de filas (0 = fin, -1 = error) */
long tco_fetch(long h, char* err, long errlen) {
    TcoResult* r = (TcoResult*)h;
    SQLRETURN rc;
    if (!r || r->cols <= 0) return 0;
    r->fetched = 0;
    rc = p_Fetch(r->stmt);
    if (rc == SQL_NO_DATA) return 0;
    if (!SQL_OK(rc)) { tco_diag(SQL_HANDLE_STMT, r->stmt, err, errlen); return -1; }
    return (long)r->fetched;
}

/* copia el valor (fila 1..n del bloque, columna 1..cols) a out; devuelve el largo o -1 si es NULL */
long tco_get(long h, long row, long col, char* out, long outlen) {
    TcoResult* r = (TcoResult*)h;
    long n, c = col - 1, i = row - 1;
    char* v;
    if (!r || c < 0 || c >= r->cols || i < 0 || i >= r->block || outlen <= 0) return 0;
    n = r->ind[c][i];
    if (n == SQL_NULL_DATA) { out[0] = 0; return -1; }
    if (n > r->width[c] - 1) n = r->width[c] - 1;                  /* truncado por el driver */
    if (n > outlen - 1) n = outlen - 1;
    v = r->buf[c] + i * r->width[c];
    tco_copy(out, v, n);
    out[n] = 0;
    return n;
}

}  /* extern "C" */
