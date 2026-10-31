"""Extrae la hoja PCGE 2026 sin Excel instalado ni dependencias adicionales.

Uso: python tools/generar_pcge.py "ruta/al/libro.xlsx"
"""
import argparse
import hashlib
import json
from pathlib import Path
import posixpath
import re
import xml.etree.ElementTree as ET
import zipfile

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def extraer(ruta):
    with zipfile.ZipFile(ruta) as archivo:
        cadenas = []
        if "xl/sharedStrings.xml" in archivo.namelist():
            cadenas = [
                "".join(t.text or "" for t in s.iterfind(".//m:t", NS))
                for s in ET.fromstring(archivo.read("xl/sharedStrings.xml"))
            ]
        relaciones = {
            r.attrib["Id"]: r.attrib["Target"]
            for r in ET.fromstring(archivo.read("xl/_rels/workbook.xml.rels"))
        }
        hojas = ET.fromstring(archivo.read("xl/workbook.xml")).find("m:sheets", NS)
        hoja = next((s for s in hojas if s.attrib["name"] == "PCGE 2026"), None)
        if hoja is None:
            raise ValueError('No se encuentra la hoja "PCGE 2026".')
        destino = relaciones[hoja.attrib[
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        ]]
        destino = destino.lstrip("/") if destino.startswith("/") else posixpath.normpath("xl/" + destino)
        datos = ET.fromstring(archivo.read(destino))
        cuentas = []
        vistos = set()
        for fila in datos.findall(".//m:sheetData/m:row", NS):
            celdas = {}
            for celda in fila.findall("m:c", NS):
                valor = celda.find("m:v", NS)
                texto = valor.text if valor is not None else ""
                if celda.attrib.get("t") == "s" and texto:
                    texto = cadenas[int(texto)]
                elif celda.attrib.get("t") == "inlineStr":
                    texto = "".join(t.text or "" for t in celda.iterfind(".//m:t", NS))
                celdas[re.sub(r"\d", "", celda.attrib["r"])] = texto or ""
            codigo = celdas.get("A", "").strip()
            if not codigo.isdigit():
                continue
            nombre = celdas.get("B", "").strip()
            nivel = int(celdas.get("C", "0"))
            if codigo in vistos or not nombre or nivel != len(codigo):
                raise ValueError(f"Cuenta duplicada o incompleta en fila {fila.attrib['r']}: {codigo}")
            vistos.add(codigo)
            cuentas.append({"codigo": codigo, "nombre": nombre, "nivel": nivel})
        if not cuentas:
            raise ValueError("El catálogo está vacío.")
        return cuentas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("excel", type=Path)
    parser.add_argument("--salida", type=Path, default=Path(__file__).resolve().parents[1] / "assets/pcge.json")
    args = parser.parse_args()
    cuentas = extraer(args.excel)
    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text(json.dumps(cuentas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    origen = {"archivo": args.excel.name, "hoja": "PCGE 2026", "cuentas": len(cuentas),
              "sha256": hashlib.sha256(args.excel.read_bytes()).hexdigest()}
    args.salida.with_name("pcge_origen.json").write_text(
        json.dumps(origen, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(cuentas)} cuentas exportadas a {args.salida}")


if __name__ == "__main__":
    main()
