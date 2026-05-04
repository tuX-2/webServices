const ORQUESTADOR = "http://192.168.20.123:8000/api/v1";

let datosGlobales = [];
let datosConsulta = null;

async function consultar(filtro) {

    let matricula = document.getElementById("matricula").value;

    if (!matricula) {
        alert("Ingrese una matrícula");
        return;
    }

    let resp = await fetch(`${ORQUESTADOR}/constancia/${matricula}`);

    let data = await resp.json();

    datosConsulta = data;

    document.getElementById("nombre").innerText =
        data.nombre_alumno || "No disponible";

    document.getElementById("estatus").innerText =
        data.estatus;

    datosGlobales = data.detalles;

    mostrarDatos(filtro);

}


function mostrarDatos(filtro) {

    let tabla = document.getElementById("tabla");

    tabla.innerHTML = "";

    let lista = datosGlobales;

    if (filtro !== "todos") {

        lista = datosGlobales.filter(d =>
            d.departamento === filtro
        );

    }

    lista.forEach(d => {

        let estado = "";
        let clase = "";

        if (!d.online) {

            estado = "OFFLINE";
            clase = "offline";

        }
        else if (d.adeudo) {

            estado = "ADEUDO";
            clase = "bad";

        }
        else {

            estado = "OK";
            clase = "ok";

        }

        let detalle = d.detalle || d.mensaje || "";

        let row = `
<tr>
<td>${d.departamento}</td>
<td class="${clase}">${estado}</td>
<td>${d.total_pendientes ?? "-"}</td>
<td>${detalle}</td>
</tr>
`;

        tabla.innerHTML += row;

    });

}

document.getElementById("btnDescargarPDF").addEventListener("click", generarPDF);

function generarPDF() {

    if (!datosConsulta) {
        alert("Primero debes realizar una consulta");
        return;
    }

    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

    const alumno = datosConsulta.nombre_alumno;
    const matricula = datosConsulta.matricula;
    const estatus = datosConsulta.estatus;
    const fecha = datosConsulta.timestamp;

    doc.setFontSize(18);
    doc.text("Reporte de Adeudos", 14, 20);

    doc.setFontSize(12);
    doc.text(`Nombre: ${alumno}`, 14, 35);
    doc.text(`Matrícula: ${matricula}`, 14, 42);
    doc.text(`Estatus: ${estatus}`, 14, 49);
    doc.text(`Fecha: ${fecha}`, 14, 56);

    const filas = datosConsulta.detalles.map(d => [
        d.departamento,
        d.adeudo ? "SI" : "NO",
        d.total_pendientes ?? "-",
        d.detalle || d.mensaje || "-"
    ]);

    doc.autoTable({
        startY: 70,
        head: [["Departamento", "Adeudo", "Pendientes", "Mensaje"]],
        body: filas
    });

    doc.save(`adeudos_${matricula}.pdf`);
}