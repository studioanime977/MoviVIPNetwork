// stup genera los artefactos de distribución por arquitectura de MoviVIP.
//
// Lee el árbol del proyecto (scripts ya migrados a NEBULA, libs, panel) y
// produce, para cada arquitectura objetivo:
//
//  1. payload-<arch>.meta — descriptor firmable: versión, arquitectura,
//     validador/guard esperados, hash SHA-256 del contenido canónico del
//     árbol para esa arch, tamaño, fecha. Compatible con el formato que
//     emite cmd/packer (mismos campos).
//  2. setup-<arch>.sh — envoltorio shell autocontenido (misma plantilla
//     que el packer) listo para concatenar el stub compilado.
//  3. install-auto.sh — auto-instalador universal con el mapa MV_SHA
//     actualizado y detección de las 15 arquitecturas.
//  4. VERSION — versión publicada.
//
// El hash es del CONTENIDO CANÓNICO (CRLF normalizados a LF, orden estable),
// no del tar: dos árboles iguales dan el mismo hash en cualquier máquina.
// La firma Ed25519 la pone el packer al compilar el stub (campo "firma":
// longitud de firma esperada; 0 = pendiente de firma).
//
// Validación fail-closed antes de generar nada: sintaxis bash (Git bash en
// Windows), barrido CRLF y escaneo de secretos. Si algo falla, no se emite.
//
// Uso:
//   go run ./cmd/stup -in <arbol> -out <dist> [-version 9.0] [-arches ...]
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

func main() {
	in := flag.String("in", "", "ruta del árbol del proyecto (ARBOL DE LA SCRIP)")
	out := flag.String("out", "", "directorio de salida de la distribución")
	version := flag.String("version", "", "versión a publicar (defecto: version.txt del árbol)")
	arches := flag.String("arches", defaultArches(), "lista separada por comas de arquitecturas")
	checkOnly := flag.Bool("check-only", false, "solo valida el árbol, no genera nada")
	flag.Parse()

	if *in == "" || *out == "" {
		fmt.Fprintln(os.Stderr, "uso: stup -in <arbol> -out <dist> [-version X] [-arches ...] [-check-only]")
		os.Exit(2)
	}
	if err := run(*in, *out, *version, strings.Split(*arches, ","), *checkOnly); err != nil {
		fatal(err)
	}
}

// archTarget es una arquitectura de distribución ya normalizada.
type archTarget struct {
	Etiqueta  string // amd64, arm64, armv5... (nombre corto para ficheros)
	GOOS      string
	GOARCH    string
	GOARM     string // "5","6","7" o ""
	Validador string // movivip-lic-linux-amd64
	Guard     string // movivip-guard-linux-amd64
	SetupBin  string // setup-linux-amd64
	SetupSh   string // setup-amd64.sh
	MetaFich  string // payload-amd64.meta
}

func defaultArches() string {
	return "amd64,386,arm64,armv5,armv6,armv7,loong64,mips,mipsle,mips64,mips64le,ppc64,ppc64le,riscv64,s390x"
}

// parseArch normaliza una etiqueta a GOOS/GOARCH/GOARM.
func parseArch(t string) (archTarget, error) {
	t = strings.TrimSpace(strings.ToLower(t))
	if t == "" {
		return archTarget{}, fmt.Errorf("arquitectura vacía")
	}
	goos, etiqueta := "linux", t
	goarch, goarm := etiqueta, ""
	switch etiqueta {
	case "armv5", "armv6", "armv7":
		goarch = "arm"
		goarm = etiqueta[len("armv"):]
	case "386", "amd64", "arm64", "loong64", "mips", "mipsle", "mips64", "mips64le",
		"ppc64", "ppc64le", "riscv64", "s390x":
		// directo
	default:
		return archTarget{}, fmt.Errorf("arquitectura desconocida: %s", t)
	}
	return archTarget{
		Etiqueta:  etiqueta,
		GOOS:      goos,
		GOARCH:    goarch,
		GOARM:     goarm,
		Validador: fmt.Sprintf("movivip-lic-linux-%s", etiqueta),
		Guard:     fmt.Sprintf("movivip-guard-linux-%s", etiqueta),
		SetupBin:  fmt.Sprintf("setup-linux-%s", etiqueta),
		SetupSh:   fmt.Sprintf("setup-%s.sh", etiqueta),
		MetaFich:  fmt.Sprintf("payload-%s.meta", etiqueta),
	}, nil
}

func run(in, out, version string, arches []string, checkOnly bool) error {
	root, err := filepath.Abs(in)
	if err != nil {
		return err
	}
	if st, err := os.Stat(filepath.Join(root, "install.sh")); err != nil || st.IsDir() {
		return fmt.Errorf("%s no parece el árbol (falta install.sh)", root)
	}
	if st, err := os.Stat(filepath.Join(root, "setup.sh")); err != nil || st.IsDir() {
		return fmt.Errorf("%s no parece el árbol nuevo (falta setup.sh)", root)
	}
	if version == "" {
		version = leerVersion(root)
	}
	logf("Árbol: %s", root)
	logf("Versión: %s", version)

	var lista []archTarget
	vistas := map[string]bool{}
	for _, a := range arches {
		t, err := parseArch(a)
		if err != nil {
			return err
		}
		if vistas[t.Etiqueta] {
			continue
		}
		vistas[t.Etiqueta] = true
		lista = append(lista, t)
	}
	if len(lista) == 0 {
		return fmt.Errorf("sin arquitecturas")
	}
	logf("Arquitecturas: %d", len(lista))

	// 1. Validación fail-closed.
	if err := validarArbol(root); err != nil {
		return err
	}
	if checkOnly {
		logf("CHECK-ONLY: árbol válido")
		return nil
	}

	if err := os.MkdirAll(out, 0o755); err != nil {
		return err
	}

	// 2. Contenido canónico + hash por arquitectura.
	type firmado struct {
		t     archTarget
		hash  string
		bytes int64
		n     int
	}
	var firmados []firmado
	hashes := map[string]string{}
	for _, t := range lista {
		h, size, n, err := fingerprint(root, t)
		if err != nil {
			return fmt.Errorf("%s: %w", t.Etiqueta, err)
		}
		firmados = append(firmados, firmado{t, h, size, n})
		hashes[t.SetupBin] = h
		logf("  %s: %d archivos, %d bytes, hash %s...", t.Etiqueta, n, size, h[:16])
	}

	// 3. Metas + wrappers por arquitectura.
	for _, f := range firmados {
		meta := map[string]any{
			"version":      version,
			"arquitectura": f.t.SetupBin,
			"validador":    f.t.Validador,
			"guard":        f.t.Guard,
			"hash":         f.hash,
			"firma":        0,
			"bytes":        f.bytes,
			"generado":     time.Now().UTC().Format(time.RFC3339),
			"goos":         f.t.GOOS,
			"goarch":       f.t.GOARCH,
			"goarm":        f.t.GOARM,
		}
		mb, _ := json.MarshalIndent(meta, "", "  ")
		mb = append(mb, '\n')
		if err := os.WriteFile(filepath.Join(out, f.t.MetaFich), mb, 0o644); err != nil {
			return err
		}
		if err := escribirWrapper(filepath.Join(out, f.t.SetupSh), f.t.Etiqueta); err != nil {
			return err
		}
	}

	// 4. install-auto.sh + VERSION.
	if err := escribirInstallAuto(filepath.Join(out, "install-auto.sh"), version, hashes); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(out, "VERSION"), []byte("MoviVIP Network Setup v"+version+"\n"), 0o644); err != nil {
		return err
	}
	logf("Distribución en: %s (%d arquitecturas)", out, len(lista))
	return nil
}

// leerVersion lee version.txt del árbol ("MoviVIP Network Setup v8.2.16"
// -> "8.2.16"; si no hay, "0.0.0").
func leerVersion(root string) string {
	b, err := os.ReadFile(filepath.Join(root, "version.txt"))
	if err != nil {
		return "0.0.0"
	}
	t := strings.TrimSpace(string(b))
	if i := strings.LastIndex(t, "v"); i >= 0 {
		if v := strings.TrimSpace(t[i+1:]); v != "" {
			return v
		}
	}
	if t != "" {
		return t
	}
	return "0.0.0"
}

// fingerprint calcula el SHA-256 del contenido canónico del árbol para una
// arquitectura: rutas ordenadas + contenido con CRLF normalizados + marcador
// de arch. Excluye lo que nunca viaja (misma política que el packer).
// Devuelve hash, bytes totales y cantidad de archivos.
func fingerprint(root string, t archTarget) (string, int64, int, error) {
	var files []string
	err := filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		if omitir(filepath.ToSlash(rel)) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if info.IsDir() || !info.Mode().IsRegular() {
			return nil
		}
		if esBinarioOtraArch(rel, t.Etiqueta) {
			return nil
		}
		files = append(files, rel)
		return nil
	})
	if err != nil {
		return "", 0, 0, err
	}
	sort.Strings(files)
	h := sha256.New()
	var total int64
	fmt.Fprintf(h, "movivip-stup-v1/%s\n", t.Etiqueta)
	for _, rel := range files {
		b, err := os.ReadFile(filepath.Join(root, rel))
		if err != nil {
			return "", 0, 0, err
		}
		b = normalizar(b)
		fmt.Fprintf(h, "%s\x00%d\x00", filepath.ToSlash(rel), len(b))
		h.Write(b)
		total += int64(len(b))
	}
	sum := h.Sum(nil)
	const hextable = "0123456789abcdef"
	dst := make([]byte, len(sum)*2)
	for i, v := range sum {
		dst[i*2] = hextable[v>>4]
		dst[i*2+1] = hextable[v&0x0f]
	}
	return string(dst), total, len(files), nil
}

// esBinarioOtraArch detecta binarios precompilados de otra arquitectura por
// nombre. Los scripts .sh son multi-arch y siempre entran.
func esBinarioOtraArch(rel, etiqueta string) bool {
	base := strings.ToLower(rel)
	marcas := []string{"amd64", "386", "arm64", "armv5", "armv6", "armv7",
		"loong64", "mips", "mipsle", "mips64", "mips64le", "ppc64", "ppc64le",
		"riscv64", "s390x", "aarch64", "x86_64"}
	tieneMarca := false
	for _, m := range marcas {
		if strings.Contains(base, m) {
			tieneMarca = true
			break
		}
	}
	if !tieneMarca {
		return false
	}
	if strings.Contains(base, etiqueta) {
		return false
	}
	alias := map[string]string{"amd64": "x86_64", "arm64": "aarch64"}
	if a, ok := alias[etiqueta]; ok && strings.Contains(base, a) {
		return false
	}
	return true
}

// normalizar convierte CRLF/CR a LF para que el hash no dependa de Windows.
func normalizar(b []byte) []byte {
	if bytes.IndexByte(b, '\r') < 0 {
		return b
	}
	b = bytes.ReplaceAll(b, []byte("\r\n"), []byte("\n"))
	b = bytes.ReplaceAll(b, []byte("\r"), []byte("\n"))
	return b
}

// omitir replica la política de exclusión del packer.
func omitir(rel string) bool {
	for _, seg := range strings.Split(rel, "/") {
		if strings.HasPrefix(seg, ".") && seg != ".env" {
			return true
		}
		if seg == "__pycache__" {
			return true
		}
	}
	base := rel[strings.LastIndex(rel, "/")+1:]
	switch base {
	case "payload.meta", "payload_embed.go", "payload.bin", "payload.signed",
		"lic_embed.go", "lic.bin", "licencia.conf",
		"guard_embed.go", "guard.bin", "Thumbs.db":
		return true
	}
	for _, suf := range []string{".bak", ".old", ".orig", ".rej", ".swp", "~", ".meta", ".bkp", ".pyc", ".pyo", ".tar.gz", ".zip"} {
		if strings.HasSuffix(base, suf) {
			return true
		}
	}
	if strings.HasPrefix(base, "backup") || strings.HasPrefix(base, "log") {
		return true
	}
	return false
}

// --- validación fail-closed --------------------------------------------------

func validarArbol(root string) error {
	if err := validarSintaxis(root); err != nil {
		return err
	}
	if err := validarCRLF(root); err != nil {
		return err
	}
	if err := validarSecretos(root); err != nil {
		return err
	}
	return nil
}

// validarSintaxis corre bash -n sobre cada .sh (Git bash en Windows).
func validarSintaxis(root string) error {
	bash := ""
	for _, cand := range []string{"bash", `C:\Program Files\Git\bin\bash.exe`, `C:\Program Files\Git\usr\bin\bash.exe`} {
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			bash = cand
			break
		}
	}
	if bash == "" {
		logf("  AVISO: bash no disponible, gate de sintaxis omitido")
		return nil
	}
	var mal []string
	n := 0
	filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(p, ".sh") {
			return nil
		}
		rel, _ := filepath.Rel(root, p)
		if omitir(filepath.ToSlash(rel)) {
			return nil
		}
		n++
		if out, err := exec.Command(bash, "-n", p).CombinedOutput(); err != nil {
			mal = append(mal, rel+": "+strings.TrimSpace(string(out)))
		}
		return nil
	})
	logf("  Sintaxis: %d scripts, %d con error", n, len(mal))
	if len(mal) > 0 {
		return fmt.Errorf("sintaxis rota:\n    %s", strings.Join(mal, "\n    "))
	}
	return nil
}

// validarCRLF rechaza retornos de carro en texto (rompen shebangs en Linux).
func validarCRLF(root string) error {
	var mal []string
	filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || info.Size() > 2*1024*1024 {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(p))
		switch ext {
		case ".sh", ".conf", ".py", ".service", ".cron", ".txt", ".md":
		default:
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil || bytes.IndexByte(b, 0) >= 0 {
			return nil
		}
		if bytes.IndexByte(b, '\r') >= 0 {
			rel, _ := filepath.Rel(root, p)
			mal = append(mal, filepath.ToSlash(rel))
		}
		return nil
	})
	if len(mal) > 0 {
		return fmt.Errorf("CRLF en %d ficheros (corre setup.sh primero):\n    %s", len(mal), strings.Join(mal, "\n    "))
	}
	logf("  CRLF: limpio")
	return nil
}

// validarSecretos rechaza credenciales en claro (red mínima del packer).
func validarSecretos(root string) error {
	patrones := []string{
		"ghp_", "gho_", "github_pat_", "AIza", "BEGIN RSA PRIVATE KEY",
		"BEGIN OPENSSH PRIVATE KEY", "BEGIN EC PRIVATE KEY",
	}
	var mal []string
	filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || info.Size() > 2*1024*1024 {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(p))
		switch ext {
		case ".sh", ".conf", ".txt", ".md", ".json", ".py":
		default:
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil || bytes.IndexByte(b, 0) >= 0 {
			return nil
		}
		for _, pt := range patrones {
			if bytes.Contains(b, []byte(pt)) {
				rel, _ := filepath.Rel(root, p)
				mal = append(mal, filepath.ToSlash(rel)+": "+pt)
				break
			}
		}
		return nil
	})
	if len(mal) > 0 {
		return fmt.Errorf("posibles secretos:\n    %s", strings.Join(mal, "\n    "))
	}
	logf("  Secretos: limpio")
	return nil
}

// --- artefactos ---------------------------------------------------------------

const wrapperTemplate = `#!/bin/sh
# MoviVIPNetwork Setup — envoltorio autocontenido
# Envuelve el stub nativo (Go) con el payload cifrado y firmado.
# No requiere xxd, base64 ni openssl en el servidor.

set -u

__arch="__ARCH__"
__self="$0"

__skip=$(awk '/^#GOES_HERE$/ { print NR + 1; exit 0 }' "$__self" 2>/dev/null || echo 0)
if [ "$__skip" -eq 0 ]; then
  echo "[ERROR] envoltorio corrupto: no se encontro el marcador del stub." >&2
  exit 1
fi

__tmp=$(mktemp -d "${TMPDIR:-/tmp}/movivip-boot.XXXXXX") || exit 1
trap 'rm -rf "$__tmp"' EXIT INT TERM

__bin="$__tmp/setup-$__arch"
if ! tail -n "+$__skip" "$__self" > "$__bin" 2>/dev/null; then
  echo "[ERROR] no se pudo extraer el stub." >&2
  exit 1
fi
chmod 700 "$__bin"

__size=$(wc -c < "$__bin" 2>/dev/null || echo 0)
if [ "$__size" -lt 1000000 ]; then
  echo "[ERROR] el stub esta incompleto ($__size bytes)." >&2
  exit 1
fi

# Sin exec: exec reemplaza el proceso del shell y el trap EXIT no se ejecuta.
"$__bin" "$@"
__rc=$?
exit "$__rc"

#GOES_HERE
`

func escribirWrapper(ruta, etiqueta string) error {
	return os.WriteFile(ruta, []byte(strings.ReplaceAll(wrapperTemplate, "__ARCH__", etiqueta)), 0o755)
}

// ordenInstallAuto es el orden canónico de binarios en install-auto.sh.
var ordenInstallAuto = []string{
	"amd64", "arm64", "armv7", "armv6", "armv5", "386",
	"loong64", "mips", "mipsle", "mips64", "mips64le",
	"ppc64", "ppc64le", "riscv64", "s390x",
}

// escribirInstallAuto genera el auto-instalador universal con el mapa de
// hashes por binario y detección uname -m -> binario.
func escribirInstallAuto(ruta, version string, hashes map[string]string) error {
	var b strings.Builder
	b.WriteString("#!/usr/bin/env bash\n")
	b.WriteString("# ============================================================================\n")
	b.WriteString("# MoviVIP Network — Auto-instalador universal  (v" + version + ")\n")
	b.WriteString("# Detecta arquitectura, descarga el instalador correcto y lo ejecuta.\n")
	b.WriteString("# Generado por cmd/stup. No editar a mano.\n#\n")
	b.WriteString("# Uso:\n")
	b.WriteString("#   curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/install-auto.sh \\\n")
	b.WriteString("#     | bash -s -- TU_CLAVE_DE_LICENCIA\n")
	b.WriteString("# ============================================================================\n")
	b.WriteString("set -euo pipefail\n\n")
	b.WriteString(fmt.Sprintf("MV_VERSION=%q\n", version))
	b.WriteString("BASE=\"https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/stubs\"\n\n")
	b.WriteString("declare -A MV_SHA=(\n")
	visto := map[string]bool{}
	for _, e := range ordenInstallAuto {
		bin := "setup-linux-" + e
		if h, ok := hashes[bin]; ok && !visto[bin] {
			visto[bin] = true
			fmt.Fprintf(&b, "  [%s]=%q\n", bin, h)
		}
	}
	var resto []string
	for bin := range hashes {
		if !visto[bin] {
			resto = append(resto, bin)
		}
	}
	sort.Strings(resto)
	for _, bin := range resto {
		fmt.Fprintf(&b, "  [%s]=%q\n", bin, hashes[bin])
	}
	b.WriteString(")\n\n")
	b.WriteString(`if ! command -v curl >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl >/dev/null 2>&1
fi
command -v sha256sum >/dev/null 2>&1 || { echo "[ERROR] sha256sum no disponible" >&2; exit 1; }

KEY="${1:-}"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)     FILE="setup-linux-amd64" ;;
    aarch64|arm64)    FILE="setup-linux-arm64" ;;
    armv7l|armhf|armv7) FILE="setup-linux-armv7" ;;
    armv8l)           FILE="setup-linux-armv7" ;;
    armv6l)           FILE="setup-linux-armv6" ;;
    armv5l)           FILE="setup-linux-armv5" ;;
    i386|i686)        FILE="setup-linux-386" ;;
    loongarch64)      FILE="setup-linux-loong64" ;;
    mips64el|mips64le) FILE="setup-linux-mips64le" ;;
    mips64)           FILE="setup-linux-mips64" ;;
    mipsel)           FILE="setup-linux-mipsle" ;;
    mips)             FILE="setup-linux-mips" ;;
    ppc64le)          FILE="setup-linux-ppc64le" ;;
    ppc64)            FILE="setup-linux-ppc64" ;;
    riscv64)          FILE="setup-linux-riscv64" ;;
    s390x)            FILE="setup-linux-s390x" ;;
    *) echo "[ERROR] Arquitectura desconocida: $ARCH" >&2; exit 1 ;;
esac

(( EUID == 0 )) || { echo "[ERROR] Ejecutar como root" >&2; exit 1; }

EXPECT="${MV_SHA[$FILE]:-}"
[[ -n "$EXPECT" ]] || { echo "[ERROR] Sin hash registrado para ${FILE}" >&2; exit 1; }

TMP="/tmp/${FILE}"
URL="${BASE}/${FILE}?h=${EXPECT}"
curl -fL --progress-bar -o "$TMP" "$URL" || { echo "[ERROR] Descarga fallida" >&2; exit 1; }
chmod +x "$TMP"

ACTUAL="$(sha256sum "$TMP" | awk '{ print $1 }')"
if [[ "$EXPECT" != "$ACTUAL" ]]; then
    echo "[ERROR] SHA256 no coincide (descarga corrupta o manipulada)" >&2
    echo "  esperado: ${EXPECT}" >&2
    echo "  obtenido: ${ACTUAL}" >&2
    exit 1
fi

if [[ -n "$KEY" ]]; then
    exec "$TMP" "$KEY"
fi
exec "$TMP"
`)
	return os.WriteFile(ruta, []byte(b.String()), 0o755)
}

func logf(format string, a ...any) {
	fmt.Printf(format+"\n", a...)
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
	os.Exit(1)
}
