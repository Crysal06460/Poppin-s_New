// Script local pour prévisualiser le nouveau Mémo Mensuel
// Usage: node generate_example_memo.js
// Sortie: /tmp/memo_exemple_juin2026.pdf

const PDFDocument = require('pdfkit');
const { DateTime } = require('luxon');
const fs = require('fs');

function memoTimeToMinutes(hhmm) {
    if (!hhmm || typeof hhmm !== 'string') return null;
    const parts = hhmm.split(':');
    if (parts.length < 2) return null;
    const h = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10);
    if (isNaN(h) || isNaN(m)) return null;
    return h * 60 + m;
}

function memoFormatHours(totalHours) {
    const h = Math.floor(totalHours);
    const m = Math.round((totalHours - h) * 60);
    return `${h}h${String(m).padStart(2, '0')}`;
}

// --- Données exemple ---
const childrenData = [
    {
        childId: '1', firstName: 'Lucas', lastName: 'Martin',
        dailyRecords: [
            { dayLabel: 'Lundi 01/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Mardi 02/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi, Goûter', realHours: '9h30' },
            { dayLabel: 'Mercredi 03/06/2026', status: 'ABSENT',  arrivalTime: '',      departureTime: '',      meals: '',               realHours: 'ABSENT' },
            { dayLabel: 'Jeudi 04/06/2026',    status: 'Présent', arrivalTime: '07:45', departureTime: '18:00', meals: 'Repas du midi', realHours: '10h15' },
            { dayLabel: 'Vendredi 05/06/2026', status: 'Présent', arrivalTime: '08:00', departureTime: '16:30', meals: 'Repas du midi', realHours: '8h30' },
            { dayLabel: 'Lundi 08/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Mardi 09/06/2026',    status: 'Présent', arrivalTime: '08:15', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h15' },
            { dayLabel: 'Jeudi 11/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Vendredi 12/06/2026', status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Lundi 15/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Mardi 16/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Jeudi 18/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Vendredi 19/06/2026', status: 'ABSENT',  arrivalTime: '',      departureTime: '',      meals: '',               realHours: 'ABSENT' },
            { dayLabel: 'Lundi 22/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
            { dayLabel: 'Mardi 23/06/2026',    status: 'Présent', arrivalTime: '07:45', departureTime: '18:15', meals: 'Repas du midi, Goûter', realHours: '10h30' },
            { dayLabel: 'Jeudi 25/06/2026',    status: 'Présent', arrivalTime: '08:00', departureTime: '17:30', meals: 'Repas du midi', realHours: '9h30' },
        ],
        totalHours: 144.5, plannedHours: 140.0, totalAbsences: 2, netSalary: 687.50,
    },
    {
        childId: '2', firstName: 'Emma', lastName: 'Leclerc',
        dailyRecords: [
            { dayLabel: 'Lundi 01/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Mardi 02/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Jeudi 04/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Vendredi 05/06/2026', status: 'ABSENT',  arrivalTime: '',      departureTime: '',      meals: '',               realHours: 'ABSENT' },
            { dayLabel: 'Lundi 08/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Mardi 09/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Jeudi 11/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Vendredi 12/06/2026', status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Biberon, Repas du midi', realHours: '8h00' },
            { dayLabel: 'Lundi 15/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
            { dayLabel: 'Mardi 16/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
            { dayLabel: 'Jeudi 18/06/2026',    status: 'Présent', arrivalTime: '09:15', departureTime: '16:45', meals: 'Repas du midi',        realHours: '7h30' },
            { dayLabel: 'Vendredi 19/06/2026', status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
            { dayLabel: 'Lundi 22/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
            { dayLabel: 'Mardi 23/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
            { dayLabel: 'Jeudi 25/06/2026',    status: 'Présent', arrivalTime: '09:00', departureTime: '17:00', meals: 'Repas du midi',        realHours: '8h00' },
        ],
        totalHours: 119.5, plannedHours: 120.0, totalAbsences: 1, netSalary: 543.00,
    },
];

const assistant = { name: 'Marie Dupont', email: 'marie.dupont@exemple.fr' };
const structureName = 'Nounous du Soleil';
const periodLabel = 'juin 2026';

// --- PDF ---
async function generatePdf() {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const buffers = [];

    return new Promise((resolve, reject) => {
        doc.on('data', chunk => buffers.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(buffers)));
        doc.on('error', reject);

        const M = 40;
        const COLS = [185, 55, 55, 55, 110, 55];
        const HEADERS = ['Jour', 'Statut', 'Arrivée', 'Départ', 'Repas', 'Heures'];
        const ROW_H = 18;
        const TOTAL_W = COLS.reduce((a, b) => a + b, 0);
        const PAGE_H = 841 - M;

        function drawRow(y, cells, bold, bg) {
            if (bg) {
                doc.save().fillColor(bg).rect(M, y, TOTAL_W, ROW_H).fill().restore();
            }
            doc.save().strokeColor('#000000').lineWidth(0.5).rect(M, y, TOTAL_W, ROW_H).stroke().restore();
            let x = M;
            for (let i = 0; i < COLS.length; i++) {
                if (i > 0) {
                    doc.save().strokeColor('#000000').lineWidth(0.5)
                        .moveTo(x, y).lineTo(x, y + ROW_H).stroke().restore();
                }
                doc.font(bold ? 'Helvetica-Bold' : 'Helvetica')
                   .fontSize(8).fillColor('#000000')
                   .text(cells[i] || '', x + 3, y + 5, { width: COLS[i] - 6, lineBreak: false, ellipsis: true });
                x += COLS[i];
            }
        }

        let firstChild = true;
        for (const child of childrenData) {
            const childName = [child.firstName, child.lastName].filter(Boolean).join(' ').trim();

            if (!firstChild) doc.addPage();
            firstChild = false;

            let y = M;

            doc.font('Helvetica-Bold').fontSize(13).fillColor('#D94350')
               .text('RAPPEL', M, y, { align: 'center', width: TOTAL_W });
            y += 18;
            doc.font('Helvetica-Bold').fontSize(10).fillColor('#D94350')
               .text('Vous devez vérifier les éléments du mémo', M, y, { align: 'center', width: TOTAL_W });
            y += 16;

            doc.font('Helvetica-Bold').fontSize(14).fillColor('#000000')
               .text('MÉMO MENSUEL', M, y, { align: 'center', width: TOTAL_W });
            y += 22;

            doc.font('Helvetica-Bold').fontSize(10).fillColor('#000000').text(`Période: ${periodLabel}`, M, y);
            y += 14;
            doc.font('Helvetica-Bold').fontSize(10).text(`Enfant: ${childName}`, M, y);
            y += 18;

            drawRow(y, HEADERS, true, '#EEEEEE');
            y += ROW_H;

            for (const rec of child.dailyRecords) {
                if (y + ROW_H > PAGE_H) {
                    doc.addPage(); y = M;
                    drawRow(y, HEADERS, true, '#EEEEEE');
                    y += ROW_H;
                }
                drawRow(y, [rec.dayLabel, rec.status, rec.arrivalTime, rec.departureTime, rec.meals, rec.realHours], false, null);
                y += ROW_H;
            }

            if (y + ROW_H > PAGE_H) { doc.addPage(); y = M; }
            drawRow(y, ['TOTAL', `Absences: ${child.totalAbsences}`, '', '', '', memoFormatHours(child.totalHours)], true, '#EEEEEE');
            y += ROW_H + 10;

            doc.font('Helvetica-Oblique').fontSize(9).fillColor('#555555')
               .text('Voir le récapitulatif à la page suivante', M, y, { align: 'center', width: TOTAL_W });

            // Page récapitulatif
            doc.addPage();
            y = M;

            doc.font('Helvetica-Bold').fontSize(14).fillColor('#000000')
               .text('RÉCAPITULATIF', M, y, { align: 'center', width: TOTAL_W });
            y += 22;
            doc.font('Helvetica-Bold').fontSize(10).text(`Période: ${periodLabel}`, M, y);
            y += 14;
            doc.font('Helvetica-Bold').fontSize(10).text(`Enfant: ${childName}`, M, y);
            y += 22;

            const BOX_X = M + 40;
            const BOX_W = TOTAL_W - 80;
            const LINE_H = 22;
            const hoursDiff = child.totalHours - child.plannedHours;
            const rows = [
                ['Heures prévues au contrat:', `${child.plannedHours.toFixed(2)} heures`],
                ["Nombre d'heures réelles total:", `${child.totalHours.toFixed(2)} heures`],
                ['Écart (réel - prévu):', `${hoursDiff.toFixed(2)} heures`],
                ['Salaire net:', `${child.netSalary.toFixed(2)} €`],
                ["Nombre d'absences total:", `${child.totalAbsences}`],
            ];
            const BOX_H = rows.length * LINE_H + 20;

            doc.save().strokeColor('#000000').lineWidth(0.5).rect(BOX_X, y, BOX_W, BOX_H).stroke().restore();

            let rowY = y + 10;
            for (const [label, value] of rows) {
                doc.font('Helvetica').fontSize(10).fillColor('#000000').text(label, BOX_X + 10, rowY);
                doc.font('Helvetica-Bold').fontSize(10)
                   .text(value, BOX_X + 10, rowY, { width: BOX_W - 20, align: 'right' });
                rowY += LINE_H;
            }
        }

        doc.end();
    });
}

(async () => {
    console.log('🔄 Génération du mémo exemple...');
    const buf = await generatePdf();
    const out = '/tmp/memo_exemple_juin2026.pdf';
    fs.writeFileSync(out, buf);
    console.log(`✅ ${out} (${(buf.length / 1024).toFixed(1)} Ko)`);
})();
