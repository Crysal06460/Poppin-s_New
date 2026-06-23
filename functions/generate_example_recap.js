// Script local pour générer un PDF d'exemple du récap mensuel
// Usage: node generate_example_recap.js
// Le PDF sera généré dans /tmp/recap_exemple.pdf

const PDFDocument = require('pdfkit');
const { DateTime } = require('luxon');
const fs = require('fs');
const path = require('path');

const CATEGORY_LABELS = {
    horaires: 'Horaires',
    repas: 'Repas',
    activites: 'Activités',
    siestes: 'Siestes',
    changes: 'Changes',
    sante: 'Santé',
    transmissions: 'Transmissions',
};

const DAY_CATEGORY_KEYS = ['horaires', 'repas', 'activites', 'siestes', 'changes', 'sante', 'transmissions'];

// --- Données fictives réalistes ---

const assistant = { name: 'Marie Dupont', email: 'marie.dupont@exemple.fr' };
const structureName = 'Nounous du Soleil';
const period = {
    start: DateTime.fromISO('2026-05-01', { zone: 'Europe/Paris' }),
    end: DateTime.fromISO('2026-06-01', { zone: 'Europe/Paris' }),
    label: 'mai 2026',
};

const childrenReports = [
    {
        childId: '1',
        firstName: 'Lucas',
        lastName: 'Martin',
        days: {
            '2026-05-02': {
                horaires: [{ segments: [{ arrivee: '08:00', depart: '17:30' }] }],
                repas: [
                    { moment: 'Déjeuner', typeAlimentation: 'Solide', qualite: 'Bien mangé', observations: 'A adoré les carottes' },
                    { moment: 'Goûter', typeAlimentation: 'Solide', qualite: 'Bien mangé' },
                ],
                siestes: [{ heure: '13:00', duration: '1h30', qualite: 'Bonne' }],
                activites: [{ type: 'Dessin', participation: 'Très enthousiaste' }],
                changes: [
                    { heure: '09:30', pipi: true, selles: false },
                    { heure: '14:00', pipi: true, selles: true, soins: ['crème'] },
                ],
                sante: [],
                transmissions: [{ category: 'Humeur', content: 'Très bonne journée, souriant toute la journée' }],
            },
            '2026-05-05': {
                horaires: [{ segments: [{ arrivee: '07:45', depart: '18:00' }] }],
                repas: [
                    { moment: 'Déjeuner', typeAlimentation: 'Solide', qualite: 'Bien mangé' },
                ],
                siestes: [{ heure: '13:15', duration: '2h00', qualite: 'Très bonne' }],
                activites: [
                    { type: 'Jeux extérieurs', participation: 'Actif' },
                    { type: 'Lecture', participation: 'Calme et attentif' },
                ],
                changes: [{ heure: '10:00', pipi: true }],
                sante: [{ heure: '11:30', type: 'Température', temperature: '37.2', route: 'axillaire' }],
                transmissions: [],
            },
            '2026-05-06': {
                horaires: [{ absent: true }],
                repas: [],
                siestes: [],
                activites: [],
                changes: [],
                sante: [],
                transmissions: [],
            },
            '2026-05-07': {
                horaires: [{ segments: [{ arrivee: '08:15', depart: '17:00' }] }],
                repas: [
                    { moment: 'Déjeuner', typeAlimentation: 'Solide', qualite: 'Peu mangé', observations: 'Fatigué' },
                    { typeAlimentation: 'Biberon', ml: 180, moment: '' },
                ],
                siestes: [{ heure: '13:00', duration: '1h00', qualite: 'Agitée' }],
                activites: [{ type: 'Éveil musical', participation: 'Participatif' }],
                changes: [{ heure: '09:00', pipi: true }, { heure: '14:30', pipi: true, selles: true }],
                sante: [{ type: 'Médicaments', medicationType: 'Doliprane 2.5 ml', heure: '10:00', observations: 'Sur ordonnance parentale' }],
                transmissions: [{ category: 'Dents', content: 'Nouvelle dent qui perce, un peu grincheux' }],
            },
            '2026-05-12': {
                horaires: [{ segments: [{ arrivee: '08:00', depart: '16:30', km: 5 }] }],
                repas: [
                    { moment: 'Déjeuner', typeAlimentation: 'Mixte', qualite: 'Bien mangé' },
                    { moment: 'Goûter', typeAlimentation: 'Solide', qualite: 'Bien mangé' },
                ],
                siestes: [{ heure: '12:45', duration: '1h45', qualite: 'Bonne' }],
                activites: [{ type: 'Sortie parc', participation: 'Joyeux', observations: 'Premiers pas sur le toboggan' }],
                changes: [{ heure: '09:30', pipi: true }, { heure: '15:00', pipi: true }],
                sante: [],
                transmissions: [{ category: 'Développement', content: 'Commence à courir, très fier de lui !' }],
            },
        },
    },
    {
        childId: '2',
        firstName: 'Emma',
        lastName: 'Leclerc',
        days: {
            '2026-05-02': {
                horaires: [{ segments: [{ arrivee: '09:00', depart: '17:00' }] }],
                repas: [
                    { typeAlimentation: 'Allaitement', moment: 'Matin' },
                    { moment: 'Déjeuner', typeAlimentation: 'Solide', qualite: 'Bien mangé' },
                ],
                siestes: [{ heure: '10:30', duration: '45min', qualite: 'Légère' }, { heure: '13:30', duration: '1h15', qualite: 'Profonde' }],
                activites: [{ type: 'Éveil sensoriel', participation: 'Curieuse' }],
                changes: [{ heure: '09:30', pipi: true }, { heure: '12:00', pipi: true, selles: true, soins: ['lingette', 'crème'] }, { heure: '15:30', pipi: true }],
                sante: [],
                transmissions: [{ category: 'Humeur', content: 'Belle journée, beaucoup de sourires' }],
            },
            '2026-05-05': {
                horaires: [{ segments: [{ arrivee: '08:30', depart: '17:30' }] }],
                repas: [
                    { typeAlimentation: 'Biberon', ml: 150, moment: 'Matin' },
                    { moment: 'Déjeuner', typeAlimentation: 'Mixte', qualite: 'Bien mangé', alimentationDescription: 'Purée carotte-courgette' },
                    { typeAlimentation: 'Biberon', ml: 120, moment: 'Goûter' },
                ],
                siestes: [{ heure: '11:00', duration: '1h00', qualite: 'Bonne' }, { heure: '14:00', duration: '1h30', qualite: 'Très bonne' }],
                activites: [{ type: 'Tapis d\'éveil', participation: 'Active' }],
                changes: [{ heure: '09:00', pipi: true }, { heure: '13:00', pipi: true }, { heure: '16:00', pipi: true, selles: true }],
                sante: [{ type: 'Poids', weight: '7.8', heure: '09:30' }],
                transmissions: [{ category: 'Alimentation', content: 'A bien accepté la purée maison, appétit au beau fixe' }],
            },
            '2026-05-14': {
                horaires: [{ segments: [{ arrivee: '09:00', depart: '16:00' }] }],
                repas: [
                    { typeAlimentation: 'Biberon', ml: 160, moment: 'Matin' },
                    { moment: 'Déjeuner', typeAlimentation: 'Solide', qualite: 'Peu mangé', observations: 'Percée dentaire' },
                ],
                siestes: [{ heure: '13:00', duration: '2h00', qualite: 'Très bonne' }],
                activites: [],
                changes: [{ heure: '09:30', pipi: true }, { heure: '14:00', pipi: true, selles: true }],
                sante: [{ type: 'Température', temperature: '37.8', route: 'axillaire', heure: '15:00', observations: 'Légère fièvre, parents prévenus' }],
                transmissions: [{ category: 'Santé', content: 'Gencives gonflées, légèrement fébrile en fin de journée — parents informés par message' }],
            },
        },
    },
];

// --- Copie exacte des fonctions du Cloud ---

function formatTimeValue(value) {
    if (!value) return '';
    if (typeof value === 'string') return value;
    if (typeof value.toDate === 'function') {
        const dt = DateTime.fromJSDate(value.toDate(), { zone: 'Europe/Paris' });
        if (dt.isValid) return dt.toFormat('HH:mm');
    }
    if (value instanceof Date) {
        const dt = DateTime.fromJSDate(value, { zone: 'Europe/Paris' });
        if (dt.isValid) return dt.toFormat('HH:mm');
    }
    return '';
}

function formatEventLines(category, entry) {
    const lines = [];
    const baseTime = formatTimeValue(entry.heure || entry.time || entry.date || entry.timestamp || entry.exactTime);

    switch (category) {
        case 'horaires': {
            if (entry.absent) { lines.push('Enfant absent.'); break; }
            if (Array.isArray(entry.segments) && entry.segments.length > 0) {
                entry.segments.forEach((segment) => {
                    const arrivee = formatTimeValue(segment.arrivee);
                    const depart = formatTimeValue(segment.depart);
                    if (arrivee) lines.push(`Arrivée : ${arrivee}`);
                    if (depart) {
                        let departLine = `Départ : ${depart}`;
                        if (segment.km !== undefined && segment.km !== null && segment.km !== '') departLine += ` (km : ${segment.km})`;
                        lines.push(departLine);
                    }
                });
            } else {
                if (entry.arrivee) lines.push(`Arrivée : ${entry.arrivee}`);
                if (entry.depart) lines.push(`Départ : ${entry.depart}`);
                if (entry.km) lines.push(`Kilomètres déclarés : ${entry.km}`);
            }
            break;
        }
        case 'repas': {
            const rawMoment = (entry.moment || '').toString();
            const momentLabel = rawMoment || (entry.gouter ? 'Goûter' : '');
            const rawType = (entry.typeAlimentation || '').toString();
            const isBiberon = entry.biberon || rawType === 'Biberon';
            const isAllaitement = entry.allaitement || rawType === 'Allaitement';
            const isSolide = rawType === 'Solide';
            const isMixte = rawType === 'Mixte';
            const typeLabel = rawType || (entry.biberon ? 'Biberon' : entry.allaitement ? 'Allaitement' : momentLabel || 'Repas');
            const descriptionAlim = (entry.alimentationDescription || '').toString();
            const qualite = (entry.qualite || '').toString();
            let description = baseTime ? `${baseTime} - ` : '';
            let detail;
            if (isBiberon) {
                detail = `Biberon ${entry.ml ? `${entry.ml} ml` : ''}`.trim();
            } else if (isAllaitement) {
                detail = 'Allaitement';
            } else if (isSolide || isMixte) {
                const descOrQualite = descriptionAlim || qualite;
                detail = descOrQualite ? `${typeLabel} - ${descOrQualite}` : typeLabel;
            } else if (qualite) {
                detail = qualite;
            } else {
                detail = typeLabel || 'Repas';
            }
            if (momentLabel && !detail.startsWith(momentLabel)) {
                description += `${momentLabel} - ${detail}`;
            } else {
                description += detail;
            }
            lines.push(description.trim());
            if (entry.observations) lines.push(`Observations : ${entry.observations}`);
            break;
        }
        case 'activites': {
            const type = entry.type || 'Activité';
            const participation = entry.participation || entry.attitude;
            let description = baseTime ? `${baseTime} - ${type}` : type;
            if (participation) description += ` (${participation})`;
            lines.push(description);
            if (entry.observations) lines.push(`Observations : ${entry.observations}`);
            break;
        }
        case 'siestes': {
            let description = baseTime ? `${baseTime} - Sieste` : 'Sieste';
            if (entry.duration) description += `, durée : ${entry.duration}`;
            if (entry.qualite) description += `, qualité : ${entry.qualite}`;
            lines.push(description);
            if (entry.observations) lines.push(`Observations : ${entry.observations}`);
            break;
        }
        case 'changes': {
            let description = baseTime ? `${baseTime} - Change ${entry.type || ''}`.trim() : `Change ${entry.type || ''}`.trim();
            const details = [];
            if (entry.pipi) details.push('pipi');
            if (entry.selles) details.push('selles');
            if (details.length) description += ` (${details.join(', ')})`;
            lines.push(description);
            if (Array.isArray(entry.soins) && entry.soins.length) lines.push(`Soins : ${entry.soins.join(', ')}`);
            if (entry.observations) lines.push(`Observations : ${entry.observations}`);
            break;
        }
        case 'sante': {
            let description = baseTime ? `${baseTime} - ${entry.type || 'Suivi santé'}` : (entry.type || 'Suivi santé');
            if (entry.type === 'Température' && entry.temperature) {
                description += ` : ${entry.temperature}°`;
                if (entry.route) description += ` (${entry.route})`;
            } else if (entry.type === 'Poids' && entry.weight) {
                description += ` : ${entry.weight} kg`;
            } else if (entry.type === 'Médicaments' && entry.medicationType) {
                description += ` : ${entry.medicationType}`;
            }
            lines.push(description);
            if (entry.observations) lines.push(`Observations : ${entry.observations}`);
            break;
        }
        case 'transmissions': {
            let description = baseTime ? `${baseTime} - ${entry.category || 'Transmission'}` : (entry.category || 'Transmission');
            if (entry.content) description += ` : ${entry.content}`;
            lines.push(description);
            break;
        }
        default: break;
    }

    return lines.filter((line) => line && line.toString().trim().length > 0);
}

// --- Génération PDF ---

async function generateMonthlyPdf({ assistant, structureName, period, childrenReports }) {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const buffers = [];

    return new Promise((resolve, reject) => {
        doc.on('data', (chunk) => buffers.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(buffers)));
        doc.on('error', reject);

        const startLabel = period.start.setLocale('fr').toFormat('dd/LL/yyyy');
        const endLabel = period.end.minus({ days: 1 }).setLocale('fr').toFormat('dd/LL/yyyy');

        doc.font('Helvetica-Bold').fontSize(20).text('Récapitulatif mensuel', { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(14).text(`Période : ${startLabel} au ${endLabel}`, { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(12).font('Helvetica').text(`Structure : ${structureName}`);
        doc.text(`Assistante : ${assistant.name || assistant.email}`);
        doc.text(`Mois : ${period.label}`);
        doc.moveDown(1);

        let firstChild = true;
        for (const report of childrenReports) {
            if (!firstChild) doc.addPage();
            firstChild = false;

            const childName = [report.firstName, report.lastName].filter(Boolean).join(' ').trim() || `Enfant ${report.childId}`;
            doc.font('Helvetica-Bold').fontSize(16).text(childName);
            doc.moveDown(0.3);

            const dayKeys = Object.keys(report.days).sort();
            if (dayKeys.length === 0) {
                doc.font('Helvetica-Italic').fontSize(12).text('Aucune donnée enregistrée pour cette période.');
                continue;
            }

            for (const dayKey of dayKeys) {
                const dayData = report.days[dayKey];
                const displayDate = DateTime.fromISO(dayKey, { zone: 'Europe/Paris' })
                    .setLocale('fr')
                    .toFormat('cccc dd LLLL yyyy');

                doc.moveDown(0.4);
                doc.font('Helvetica-Bold').fontSize(13).fillColor('#3D9DF2').text(displayDate);
                doc.fillColor('black');
                doc.moveDown(0.2);

                for (const category of DAY_CATEGORY_KEYS) {
                    const events = dayData[category];
                    if (!events || events.length === 0) continue;

                    doc.font('Helvetica-Bold').fontSize(12).text(CATEGORY_LABELS[category]);
                    doc.moveDown(0.1);
                    for (const entry of events) {
                        const lines = formatEventLines(category, entry);
                        if (!lines.length) continue;
                        doc.font('Helvetica').fontSize(11).text(`• ${lines[0]}`);
                        for (let i = 1; i < lines.length; i++) doc.text(`  ${lines[i]}`);
                        doc.moveDown(0.05);
                    }
                    doc.moveDown(0.2);
                }
            }
        }

        doc.end();
    });
}

// --- Main ---

(async () => {
    console.log('🔄 Génération du PDF d\'exemple...');
    const pdfBuffer = await generateMonthlyPdf({ assistant, structureName, period, childrenReports });
    const outputPath = '/tmp/recap_exemple_mai2026.pdf';
    fs.writeFileSync(outputPath, pdfBuffer);
    console.log(`✅ PDF généré : ${outputPath}`);
    console.log(`📄 Taille : ${(pdfBuffer.length / 1024).toFixed(1)} Ko`);
})();
