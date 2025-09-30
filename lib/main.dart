import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  runApp(const DoseEstimateApp());
}

class DoseEstimateApp extends StatelessWidget {
  const DoseEstimateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPP-742 Dose Estimate',
      theme: ThemeData(
        // Soft friendly light palette: soft blue primary, gentle teal secondary, warm background
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90E2), brightness: Brightness.light, secondary: const Color(0xFF2DB7A3), background: const Color(0xFFF7F8FA)),
        brightness: Brightness.light,
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90E2), foregroundColor: Colors.white)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF2DB7A3)),
        chipTheme: ChipThemeData(backgroundColor: const Color(0xFFEEF6FF), labelStyle: const TextStyle(color: Color(0xFF234A6B))),
        // Use an outlined style for TextFields to give more definition
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey.shade400)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: const Color(0xFF4A90E2), width: 2.0)),
          labelStyle: const TextStyle(color: Colors.black87),
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        ),
      ),
      home: const DoseHomePage(),
    );
  }
}

class DoseHomePage extends StatefulWidget {
  const DoseHomePage({super.key});

  @override
  State<DoseHomePage> createState() => _DoseHomePageState();
}

class TaskData {

  String title;
  String location;
  int workers;
  double hours;
  double mpifR;
  double mpifC;
  double mpifD;
  double mpifS;
  double mpifU;
  double doseRate;
  double pfr;
  double pfe;
  List<NuclideEntry> nuclides;
  List<ExtremityEntry> extremities;

  // Persistent controllers so cursor/selection behavior remains stable
  final TextEditingController titleController = TextEditingController();
  final FocusNode titleFocusNode = FocusNode();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController workersController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController mpifDController = TextEditingController();
  final TextEditingController mpifSController = TextEditingController();
  final TextEditingController mpifUController = TextEditingController();
  final TextEditingController doseRateController = TextEditingController();

  TaskData({
    this.title = '',
    this.location = '',
    this.workers = 1,
    this.hours = 1.0,
    // Use 0.0 to indicate 'not selected' for all mPIF inputs. UI will require selection before computing mPIF.
    this.mpifR = 0.0,
    this.mpifC = 0.0,
    this.mpifD = 0.0,
    this.mpifS = 0.0,
    this.mpifU = 0.0,
    this.doseRate = 0.0,
    this.pfr = 1.0,
    this.pfe = 1.0,
    List<NuclideEntry>? nuclides,
    List<ExtremityEntry>? extremities,
  })  : nuclides = nuclides ?? [NuclideEntry()],
        extremities = extremities ?? [] {
  titleController.text = title;
  locationController.text = location;
  workersController.text = workers.toString();
  hoursController.text = hours.toString();
  // Leave mPIF field controllers empty when value is 0.0 (not selected)
  mpifDController.text = mpifD > 0.0 ? mpifD.toString() : '';
  mpifSController.text = mpifS > 0.0 ? mpifS.toString() : '';
  mpifUController.text = mpifU > 0.0 ? mpifU.toString() : '';
  doseRateController.text = doseRate.toString();

    // keep model fields in sync with controllers
    titleController.addListener(() {
      title = titleController.text;
    });
    locationController.addListener(() {
      location = locationController.text;
    });
    workersController.addListener(() {
      workers = int.tryParse(workersController.text) ?? 1;
    });
    hoursController.addListener(() {
      hours = double.tryParse(hoursController.text) ?? 0.0;
    });
    mpifDController.addListener(() {
      mpifD = double.tryParse(mpifDController.text) ?? 0.0;
    });
    mpifSController.addListener(() {
      mpifS = double.tryParse(mpifSController.text) ?? 0.0;
    });
    mpifUController.addListener(() {
      mpifU = double.tryParse(mpifUController.text) ?? 0.0;
    });
    doseRateController.addListener(() {
      doseRate = double.tryParse(doseRateController.text) ?? 0.0;
    });
  }

  void disposeControllers() {
    titleController.dispose();
    titleFocusNode.dispose();
    locationController.dispose();
    workersController.dispose();
    hoursController.dispose();
    mpifDController.dispose();
    mpifSController.dispose();
    mpifUController.dispose();
    doseRateController.dispose();
    for (final n in nuclides) {
      n.disposeControllers();
    }
    for (final e in extremities) {
      e.disposeControllers();
    }
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'location': location,
        'workers': workers,
        'hours': hours,
        'mpifR': mpifR,
        'mpifC': mpifC,
        'mpifD': mpifD,
        'mpifS': mpifS,
        'mpifU': mpifU,
        'doseRate': doseRate,
        'pfr': pfr,
        'pfe': pfe,
        'nuclides': nuclides.map((n) => n.toJson()).toList(),
        'extremities': extremities.map((e) => e.toJson()).toList(),
      };

  static TaskData fromJson(Map<String, dynamic> j) {
    return TaskData(
      title: j['title'] ?? '',
      location: j['location'] ?? '',
      workers: j['workers'] ?? 1,
      hours: (j['hours'] ?? 1).toDouble(),
      mpifR: (j['mpifR'] ?? 1).toDouble(),
      mpifC: (j['mpifC'] ?? 100).toDouble(),
      mpifD: (j['mpifD'] ?? 1).toDouble(),
      mpifS: (j['mpifS'] ?? 1).toDouble(),
      mpifU: (j['mpifU'] ?? 1).toDouble(),
      doseRate: (j['doseRate'] ?? 0).toDouble(),
      pfr: (j['pfr'] ?? 1).toDouble(),
      pfe: (j['pfe'] ?? 1).toDouble(),
      nuclides: (j['nuclides'] as List? ?? []).map((e) => NuclideEntry.fromJson(e)).toList(),
      extremities: (j['extremities'] as List? ?? []).map((e) => ExtremityEntry.fromJson(e)).toList(),
    );
  }
}

class NuclideEntry {
  String name;
  double contam; // dpm/100cm2
  double? customDAC; // µCi/mL - only used when name is "Other"
  final TextEditingController contamController = TextEditingController();
  final TextEditingController dacController = TextEditingController();

  NuclideEntry({this.name = 'Other', this.contam = 0.0, this.customDAC}) {
    contamController.text = contam.toString();
    contamController.addListener(() {
      final parsed = double.tryParse(contamController.text);
      if (parsed != null) {
        contam = parsed;
      }
    });

    // Initialize DAC controller for "Other" nuclides
    if (name == 'Other' && customDAC != null) {
      dacController.text = customDAC!.toStringAsExponential(2);
    }
    dacController.addListener(() {
      if (name == 'Other') {
        final parsed = double.tryParse(dacController.text);
        if (parsed != null && parsed > 0) {
          customDAC = parsed;
        }
      }
    });
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'contam': contam,
    if (name == 'Other' && customDAC != null) 'customDAC': customDAC
  };

  static NuclideEntry fromJson(Map<String, dynamic> j) => NuclideEntry(
    name: j['name'] ?? 'Other',
    contam: (j['contam'] ?? 0).toDouble(),
    customDAC: j['customDAC']?.toDouble()
  );

  void disposeControllers() {
    contamController.dispose();
    dacController.dispose();
  }
}

class ExtremityEntry {
  String? nuclide;
  double doseRate;
  double time;
  final TextEditingController doseRateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();

  ExtremityEntry({this.nuclide, this.doseRate = 0.0, this.time = 0.0}) {
    // Initialize controllers with the current values
    doseRateController.text = doseRate.toString();
    timeController.text = time.toString();

    // Keep model fields in sync with controllers
    doseRateController.addListener(() {
      doseRate = double.tryParse(doseRateController.text) ?? 0.0;
    });
    timeController.addListener(() {
      time = double.tryParse(timeController.text) ?? 0.0;
    });
  }

  Map<String, dynamic> toJson() => {'nuclide': nuclide, 'doseRate': doseRate, 'time': time};
  static ExtremityEntry fromJson(Map<String, dynamic> j) => ExtremityEntry(nuclide: j['nuclide'], doseRate: (j['doseRate'] ?? 0).toDouble(), time: (j['time'] ?? 0).toDouble());

  void disposeControllers() {
    doseRateController.dispose();
    timeController.dispose();
  }
}

// Top-level Decoration that paints a rounded gradient 'frosted' indicator for tabs.
class GradientTabIndicator extends Decoration {
  final double radius;
  final Gradient gradient;
  final double blurRadius;
  /// blurRadius is used only for the shadow; the main pill is painted sharply so it stands out.
  const GradientTabIndicator({this.radius = 12.0, required this.gradient, this.blurRadius = 8.0});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _GradientPainter(radius: radius, gradient: gradient, blurRadius: blurRadius);
}

class _GradientPainter extends BoxPainter {
  final double radius;
  final Gradient gradient;
  final double blurRadius;

  _GradientPainter({required this.radius, required this.gradient, required this.blurRadius});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    if (size.isEmpty) return;
    final rect = offset & size;

    // Make the pill slightly larger than the provided rect so it reads as a 'pill' behind the label.
    const extraHorizontal = 8.0;
    const extraVertical = 6.0;
    final paddedRect = Rect.fromLTRB(rect.left - extraHorizontal, rect.top - extraVertical, rect.right + extraHorizontal, rect.bottom + extraVertical);
    final rrect = RRect.fromRectAndRadius(paddedRect, Radius.circular(radius));

    // Draw a subtle shadow first (use sigma ~= blurRadius / 2)
    final shadowSigma = (blurRadius / 2.0).clamp(0.0, 30.0);
    final shadowPaint = Paint()
  ..color = Color.fromRGBO(0, 0, 0, 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowSigma);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // Fill the pill with the provided gradient (sharp edges so it stands out).
    final fillPaint = Paint()..shader = gradient.createShader(paddedRect);
    canvas.drawRRect(rrect, fillPaint);
  }
}
class _DoseHomePageState extends State<DoseHomePage> with TickerProviderStateMixin {
  final Map<String, double> dacValues = const {
    "Ac-227": 2e-13, "Ag-108m": 5e-8, "Ag-110m": 3e-8, "Al-26": 2e-9, "Am-241": 5e-12, "Am-243": 5e-12,
    "Ar-37": 4e-5, "Ar-39": 3e-6, "Ar-41": 3e-6, "As-73": 6e-7, "As-74": 2e-7, "As-76": 2e-7, "As-77": 7e-7,
    "At-211": 2e-9, "Au-195": 2e-6, "Au-198": 2e-7, "Au-199": 3e-7, "Ba-131": 3e-7, "Ba-133": 2e-7, "Ba-140": 4e-8,
    "Be-7": 2e-6, "Be-10": 2e-8, "Bi-206": 3e-8, "Bi-207": 4e-8, "Bi-210": 2e-9, "Bi-212": 6e-8, "Bk-249": 2e-9,
    "Br-82": 3e-7, "C-11": 4e-6, "C-14": 2e-7, "Ca-41": 6e-7, "Ca-45": 9e-9, "Ca-47": 9e-8, "Cd-109": 8e-8,
    "Cd-113m": 2e-8, "Cd-115": 3e-7, "Cd-115m": 9e-8, "Ce-139": 2e-7, "Ce-141": 1e-7, "Ce-143": 1e-7, "Ce-144": 2e-9,
    "Cf-249": 3e-12, "Cf-250": 6e-12, "Cf-251": 3e-12, "Cf-252": 1e-11, "Cl-36": 2e-8, "Cl-38": 2e-6, "Cm-242": 2e-11,
    "Cm-243": 6e-12, "Cm-244": 8e-12, "Cm-245": 5e-12, "Cm-246": 5e-12, "Cm-247": 5e-12, "Cm-248": 2e-12,
    "Co-56": 1e-7, "Co-57": 4e-7, "Co-58": 2e-7, "Co-58m": 1e-5, "Co-60": 3e-9, "Co-60m": 3e-4, "Cr-51": 3e-6,
    "Cs-129": 3e-6, "Cs-131": 1e-6, "Cs-134": 2e-8, "Cs-134m": 5e-5, "Cs-135": 3e-7, "Cs-136": 4e-8, "Cs-137": 8e-8,
    "Cu-64": 6e-7, "Cu-67": 3e-7, "Dy-159": 8e-7, "Dy-165": 9e-7, "Dy-166": 3e-8, "Er-169": 1e-6, "Er-171": 4e-7,
    "Eu-152": 6e-9, "Eu-152m": 6e-7, "Eu-154": 5e-9, "Eu-155": 5e-7, "F-18": 1e-6, "Fe-52": 2e-7, "Fe-55": 2e-6,
    "Fe-59": 3e-8, "Ga-67": 1e-6, "Ga-68": 1e-6, "Ga-72": 4e-7, "Gd-146": 4e-8, "Gd-148": 2e-12, "Gd-149": 8e-7,
    "Gd-151": 2e-7, "Gd-153": 6e-7, "Gd-159": 3e-7, "Ge-68": 2e-7, "Ge-71": 2e-5, "H-3": 2e-5, "Hf-172": 1e-8,
    "Hf-175": 2e-7, "Hf-181": 7e-8, "Hg-197": 1e-6, "Hg-197m": 3e-7, "Hg-203": 2e-7, "Ho-166": 3e-8, "I-123": 6e-8,
    "I-124": 1e-8, "I-125": 4e-9, "I-126": 2e-9, "I-129": 6e-9, "I-131": 2e-8, "I-132": 8e-7, "I-133": 7e-8,
    "I-134": 2e-6, "I-135": 3e-7, "In-111": 5e-7, "In-113m": 2e-6, "In-114m": 2e-8, "In-115m": 1e-6, "Ir-190": 2e-7,
    "Ir-192": 2e-8, "Ir-194": 1e-7, "K-40": 3e-8, "K-42": 3e-6, "K-43": 6e-7, "Kr-74": 2e-6, "Kr-76": 8e-7,
    "Kr-77": 2e-6, "Kr-79": 4e-6, "Kr-81": 4e-5, "Kr-81m": 2e-4, "Kr-83m": 5e-4, "Kr-85": 1e-4, "Kr-85m": 3e-5,
    "Kr-87": 8e-6, "Kr-88": 2e-6, "La-137": 3e-7, "La-140": 2e-7, "Lu-172": 6e-8, "Lu-173": 2e-7, "Lu-174": 3e-7,
    "Lu-174m": 2e-7, "Lu-177": 6e-7, "Mn-52": 1e-7, "Mn-53": 5e-6, "Mn-54": 3e-7, "Mn-56": 1e-6, "Mo-93": 3e-7,
    "Mo-99": 2e-7, "N-13": 9e-6, "Na-22": 2e-8, "Na-24": 3e-7, "Nb-93m": 5e-6, "Nb-94": 2e-9, "Nb-95": 2e-7,
    "Nb-97": 9e-7, "Nd-144": 2e-12, "Nd-147": 2e-7, "Nd-149": 6e-7, "Ni-56": 2e-7, "Ni-57": 3e-7, "Ni-59": 2e-6,
    "Ni-63": 2e-7, "Ni-65": 5e-7, "Np-235": 2e-6, "Np-236": 2e-9, "Np-237": 5e-12, "Np-239": 3e-7, "O-15": 2e-6,
    "Os-185": 7e-7, "Os-191": 3e-7, "Os-191m": 4e-6, "Os-193": 2e-7, "P-32": 9e-9, "P-33": 5e-7, "Pa-230": 2e-8,
    "Pa-231": 2e-12, "Pa-233": 2e-7, "Pb-203": 6e-7, "Pb-210": 1e-10, "Pb-212": 8e-10, "Pd-103": 3e-6, "Pd-107": 1e-5,
    "Pd-109": 1e-6, "Pm-143": 2e-7, "Pm-144": 3e-8, "Pm-145": 3e-7, "Pm-147": 3e-7, "Pm-148": 3e-8, "Pm-148m": 4e-8,
    "Pm-149": 4e-7, "Pm-151": 5e-7, "Po-208": 3e-11, "Po-209": 2e-11, "Po-210": 4e-11, "Pr-142": 1e-7, "Pr-143": 2e-7,
    "Pt-191": 3e-7, "Pt-193": 1e-5, "Pt-193m": 1e-6, "Pt-195m": 6e-7, "Pt-197": 6e-7, "Pt-197m": 1e-6, "Pu-236": 2e-11,
    "Pu-237": 3e-6, "Pu-238": 7e-12, "Pu-239": 6e-12, "Pu-240": 6e-12, "Pu-241": 3e-10, "Pu-242": 6e-12, "Pu-244": 6e-12,
    "Ra-223": 9e-11, "Ra-224": 4e-11, "Ra-225": 8e-11, "Ra-226": 3e-11, "Ra-228": 3e-11, "Rb-81": 2e-6, "Rb-82": 6e-6,
    "Rb-83": 2e-6, "Rb-84": 1e-7, "Rb-86": 2e-8, "Rb-87": 3e-7, "Rb-88": 4e-6, "Re-184": 1e-7, "Re-184m": 3e-7,
    "Re-186": 1e-6, "Re-187": 9e-6, "Re-188": 4e-7, "Re-189": 5e-7, "Rh-99": 9e-7, "Rh-101": 4e-7, "Rh-102": 1e-7,
    "Rh-102m": 2e-7, "Rh-103m": 1e-4, "Rh-105": 1e-6, "Rn-220": 3e-8, "Rn-222": 3e-8, "Ru-97": 5e-7, "Ru-103": 3e-7,
    "Ru-105": 5e-7, "Ru-106": 3e-9, "S-35": 2e-7, "Sb-122": 3e-7, "Sb-124": 1e-7, "Sb-125": 2e-7, "Sb-126": 2e-8,
    "Sc-44": 4e-7, "Sc-44m": 2e-7, "Sc-46": 1e-7, "Sc-47": 3e-7, "Sc-48": 1e-7, "Se-72": 3e-7, "Se-73": 4e-7,
    "Se-75": 2e-7, "Se-79": 2e-6, "Si-31": 9e-7, "Si-32": 3e-8, "Sm-145": 3e-7, "Sm-147": 2e-11, "Sm-151": 3e-6,
    "Sm-153": 5e-7, "Sn-113": 2e-7, "Sn-117m": 2e-7, "Sn-119m": 4e-7, "Sn-121": 2e-6, "Sn-121m": 2e-7, "Sn-123": 8e-8,
    "Sn-125": 1e-7, "Sn-126": 1e-8, "Sr-82": 2e-7, "Sr-85": 3e-7, "Sr-85m": 1e-5, "Sr-87m": 3e-5, "Sr-89": 3e-8,
    "Sr-90": 7e-9, "Sr-91": 3e-7, "Sr-92": 1e-6, "Ta-178": 1e-7, "Ta-179": 3e-7, "Ta-182": 4e-8, "Tb-157": 2e-7,
    "Tb-158": 5e-9, "Tb-160": 4e-8, "Tc-94": 1e-6, "Tc-94m": 2e-6, "Tc-95": 1e-6, "Tc-95m": 6e-7, "Tc-96": 2e-7,
    "Tc-96m": 1e-5, "Tc-97": 4e-6, "Tc-97m": 1e-6, "Tc-98": 8e-9, "Tc-99": 2e-6, "Tc-99m": 2e-5, "Te-121": 2e-6,
    "Te-121m": 2e-7, "Te-123": 5e-7, "Te-123m": 2e-7, "Te-125m": 3e-7, "Te-127": 7e-7, "Te-127m": 1e-7, "Te-129": 7e-7,
    "Te-129m": 8e-8, "Te-131": 4e-7, "Te-131m": 1e-7, "Te-132": 2e-7, "Th-227": 8e-12, "Th-228": 2e-12, "Th-229": 5e-13,
    "Th-230": 7e-13, "Th-231": 4e-7, "Th-232": 3e-13, "Th-234": 3e-9, "Ti-44": 2e-9, "Tl-200": 9e-7, "Tl-201": 1e-6,
    "Tl-202": 3e-7, "Tl-204": 2e-7, "Tm-167": 7e-7, "Tm-170": 2e-7, "Tm-171": 8e-7, "U-230": 3e-11, "U-232": 1e-11,
    "U-233": 9e-11, "U-234": 1e-10, "U-235": 8e-11, "U-236": 1e-10, "U-237": 7e-7, "U-238": 1e-10, "U-239": 5e-7,
    "U-240": 3e-7, "V-48": 2e-7, "V-49": 1e-5, "W-178": 9e-6, "W-181": 8e-6, "W-185": 8e-7, "W-187": 2e-6, "W-188": 3e-7,
    "Xe-122": 4e-7, "Xe-123": 2e-7, "Xe-125": 3e-7, "Xe-127": 4e-7, "Xe-129m": 4e-6, "Xe-131m": 1e-5, "Xe-133": 3e-5,
    "Xe-133m": 1e-5, "Xe-135": 1e-5, "Xe-135m": 2e-5, "Xe-138": 1e-5, "Y-86": 1e-7, "Y-87": 2e-7, "Y-88": 1e-7,
    "Y-90": 2e-8, "Y-91": 2e-8, "Y-91m": 2e-5, "Y-92": 2e-7, "Y-93": 1e-7, "Yb-169": 2e-7, "Yb-175": 9e-7,
    "Zn-62": 2e-7, "Zn-63": 9e-7, "Zn-65": 1e-7, "Zn-69": 6e-6, "Zn-69m": 3e-7, "Zr-88": 3e-7, "Zr-89": 1e-7,
    "Zr-93": 5e-8, "Zr-95": 1e-7, "Zr-97": 2e-7, "Other": 2e-13
  };

  final Map<String, double> releaseFactors = const {
    'Gases, volatile liquids (1.0)': 1.0,
    'Nonvolatile powders, some liquids (0.1)': 0.1,
    'Liquids, large area contamination (0.01)': 0.01,
    'Solids, spotty contamination (0.001)': 0.001,
    'Encapsulated material (0)': 0
  };

  final Map<String, double> confinementFactors = const {
    'None - Open bench (100)': 100,
    'Bagged material (10)': 10,
    'Fume Hood (1.0)': 1.0,
    'Enhanced Fume Hood (0.1)': 0.1,
    'Glovebox, Hot Cell (0.01)': 0.01
  };

  List<TaskData> tasks = [];
  TextEditingController workOrderController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  // user overrides for trigger checkboxes
  Map<String, bool> triggerOverrides = {};
  // justifications for overrides
  Map<String, String> overrideJustifications = {};

  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 1, vsync: this);
    tasks = [];
  }

  // A lightweight Decoration for a gradient/frosted tab indicator.
  // It paints a rounded rectangle with a subtle gradient and shadow behind the active tab.
  // (GradientTabIndicator moved to top-level to avoid nested class declaration errors.)

  @override
  void dispose() {
    workOrderController.dispose();
    descriptionController.dispose();
    dateController.dispose();
    for (final t in tasks) {
      t.disposeControllers();
    }
    tabController.dispose();
    super.dispose();
  }

  void addTask([TaskData? data]) {
    setState(() {
      tasks.add(data ?? TaskData());
      tabController = TabController(length: tasks.length + 1, vsync: this);
      tabController.index = tasks.length; // switch to new task tab
    });
    // Request focus on the new task title after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tasks.isNotEmpty) {
        try {
          tasks.last.titleFocusNode.requestFocus();
        } catch (_) {}
      }
    });
  }

  void removeTask(int index) {
    setState(() {
      // dispose controllers for the task being removed
      tasks[index].disposeControllers();
      tasks.removeAt(index);
      tabController = TabController(length: tasks.length + 1, vsync: this);
      tabController.index = 0;
    });
  }

  double computeMPIF(TaskData t) {
    // require all mPIF factors to be selected (non-zero) before computing
    if (t.mpifR <= 0.0 || t.mpifC <= 0.0 || t.mpifD <= 0.0 || t.mpifS <= 0.0 || t.mpifU <= 0.0) {
      return 0.0; // sentinel meaning 'not set'
    }
    // ensure all multipliers are treated as doubles and avoid integer-only arithmetic
    final mPIF = 1e-6 * (t.mpifR) * (t.mpifC) * (t.mpifD) * 1.0 * (t.mpifS) * (t.mpifU);
    return mPIF;
  }

  // Calculate task totals similar to the JS version
  Map<String, double> calculateTaskTotals(TaskData t) {
    final workers = t.workers;
    final hours = t.hours;
    final personHours = workers * hours;
    final mPIF = computeMPIF(t);

    // We'll compute a few different intermediate values for clarity and triggers:
    // - dacFractionRaw: airConc / dac (before any protections)
    // - dacFractionEngOnly: dacFractionRaw / PFE (after engineering controls only)
    // - dacFractionWithResp: dacFractionRaw / (PFE * PFR) used for certain trigger calculations
    double totalDacFraction = 0.0; // current UI field (post-PFE sum)
  double totalDacFractionEngOnly = 0.0; // sum after engineering controls only
    double totalDacFractionWithResp = 0.0; // sum after both eng + resp (used for some triggers)
    double totalCollectiveInternal = 0.0;
    double totalCollectiveInternalUnprotected = 0.0;
  double totalCollectiveInternalAfterPFE = 0.0;

    for (final n in t.nuclides) {
      final res = computeNuclideDose(n, t);
      final dacFractionEngOnly = res['dacFractionEngOnly'] ?? 0.0;
      final dacFractionWithBoth = res['dacFractionWithBoth'] ?? 0.0;
      final nuclideDoseAfterBoth = res['collective'] ?? 0.0;
      final nuclideDoseUnprotected = res['unprotected'] ?? 0.0;
      final nuclideDoseAfterPFE = res['afterPFE'] ?? 0.0;

      totalDacFraction += dacFractionEngOnly;
      totalDacFractionEngOnly += dacFractionEngOnly;
      totalDacFractionWithResp += dacFractionWithBoth;

      totalCollectiveInternal += nuclideDoseAfterBoth;
      totalCollectiveInternalUnprotected += nuclideDoseUnprotected;
      totalCollectiveInternalAfterPFE += nuclideDoseAfterPFE;
    }

    final collectiveExternal = t.doseRate * personHours;
    final collectiveEffective = collectiveExternal + totalCollectiveInternal;
    final individualEffective = workers > 0 ? collectiveEffective / workers : 0.0;

    // Calculate extremity dose ONLY from manually entered extremity entries
    // Each entry contributes: doseRate (mrem/hr) * time (hr) = total mrem per person
    double totalExtremityDose = 0.0;
    for (final e in t.extremities) {
      // Only include entries with positive dose rate AND time
      if (e.doseRate > 0.0 && e.time > 0.0) {
        totalExtremityDose += e.doseRate * e.time;
      }
    }

  // totalExtremityDose currently holds per-person extremity dose (sum of e.doseRate*e.time)
  final individualExtremity = totalExtremityDose;
  final collectiveExtremity = totalExtremityDose * workers;

  return {
      'personHours': personHours,
      'mPIF': mPIF,
      'totalDacFraction': totalDacFraction, // post-PFE (what the UI previously showed)
      'totalDacFractionEngOnly': totalDacFractionEngOnly,
      'totalDacFractionWithResp': totalDacFractionWithResp,
  'collectiveInternal': totalCollectiveInternal,
  'collectiveInternalUnprotected': totalCollectiveInternalUnprotected,
  'collectiveInternalAfterPFE': totalCollectiveInternalAfterPFE,
      'collectiveExternal': collectiveExternal,
      'collectiveEffective': collectiveEffective,
      'individualEffective': individualEffective,
      // keep backwards compatibility: 'totalExtremityDose' represents the collective extremity
      // so that callers dividing by workers obtain the per-person dose as before.
      'totalExtremityDose': collectiveExtremity,
      'individualExtremity': individualExtremity,
      'collectiveExtremity': collectiveExtremity,
    };
  }

  // Format numbers for display: use plain formatting for readable ranges,
  // exponential only when very small or very large.
  String formatNumber(double v) {
    final av = v.abs();
    if (av == 0.0) return '0';
    // Use exponential notation for extremes
    if ((av < 0.001 && av > 0) || av >= 1e6) {
      return v.toStringAsExponential(2);
    }

    // For normal-range values, round to three decimal places for cleaner UI.
    // Keep sign and format with fixed 3 decimals.
    return v.toStringAsFixed(3);
  }

  // Get DAC value for a nuclide, using custom DAC for "Other" nuclides
  double getDAC(NuclideEntry n) {
    if (n.name == 'Other' && n.customDAC != null && n.customDAC! > 0) {
      return n.customDAC!;
    }
    return dacValues[n.name] ?? 1e-12;
  }

  // Compute per-nuclide dose components in one place to keep UI and totals consistent.
  Map<String, double> computeNuclideDose(NuclideEntry n, TaskData t) {
    final dac = getDAC(n);
    final safeDac = (dac == 0.0) ? 1e-12 : dac;
    final mPIF = computeMPIF(t);
    final airConc = (n.contam / 100) * mPIF * (1 / 100) * (1 / 2.22e6);
    final dacFractionRaw = (airConc / safeDac);
    final dacFractionEngOnly = dacFractionRaw / (t.pfe == 0.0 ? 1.0 : t.pfe);
    final dacFractionWithBoth = dacFractionRaw / ((t.pfe == 0.0 ? 1.0 : t.pfe) * (t.pfr == 0.0 ? 1.0 : t.pfr));

    final workers = t.workers;
    final personHours = workers * t.hours;

    // Unprotected collective dose
    final unprotected = dacFractionRaw * (personHours / 2000) * 5000;
    final afterPFE = dacFractionEngOnly * (personHours / 2000) * 5000;
    final collective = dacFractionEngOnly * (personHours / 2000) * 5000 / (t.pfr == 0.0 ? 1.0 : t.pfr);

    return {
      'dac': dac,
      'airConc': airConc,
      'dacFractionRaw': dacFractionRaw,
      'dacFractionEngOnly': dacFractionEngOnly,
      'dacFractionWithBoth': dacFractionWithBoth,
      'unprotected': unprotected,
      'afterPFE': afterPFE,
      'collective': collective,
      'individual': workers > 0 ? collective / workers : 0.0,
    };
  }

  /// Compute global ALARA and air-sampling triggers across all tasks.
  Map<String, dynamic> computeGlobalTriggers() {
    double totalIndividualEffectiveDose = 0.0;
    double totalIndividualExtremityDose = 0.0;
    double totalCollectiveDose = 0.0;

    double maxDacHrsWithResp = 0.0;
    double maxDacSpikeEngOnly = 0.0;
    double maxDacHrsEngOnly = 0.0;
    double maxContamination = 0.0;
    double maxDoseRate = 0.0;

    for (final t in tasks) {
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      final individualExternal = workers > 0 ? (totals['collectiveExternal']! / workers) : 0.0;
      final individualInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
      totalIndividualEffectiveDose += individualExternal + individualInternal;
      totalIndividualExtremityDose += workers > 0 ? (totals['totalExtremityDose']! / workers) : 0.0;
      totalCollectiveDose += totals['collectiveEffective']!;

      maxDoseRate = maxDoseRate > t.doseRate ? maxDoseRate : t.doseRate;

      double taskDacWithResp = 0.0;
      double taskDacEngOnly = 0.0;

      for (final n in t.nuclides) {
        final contam = n.contam;
        final dac = getDAC(n);
        final mPIF = computeMPIF(t);
        final airConc = (contam / 100) * mPIF * (1 / 100) * (1 / 2.22e6);
        final dacFractionWithBoth = (airConc / dac) / (t.pfe * t.pfr);
        final dacFractionEngOnly = (airConc / dac) / t.pfe;

        taskDacWithResp += dacFractionWithBoth;
        taskDacEngOnly += dacFractionEngOnly;

        maxContamination = maxContamination > (contam / 1000) ? maxContamination : (contam / 1000);
        maxDacSpikeEngOnly = maxDacSpikeEngOnly > taskDacEngOnly ? maxDacSpikeEngOnly : taskDacEngOnly;
      }

      final dacHrsWithResp = taskDacWithResp * t.hours;
      maxDacHrsWithResp = maxDacHrsWithResp > dacHrsWithResp ? maxDacHrsWithResp : dacHrsWithResp;

      final dacHrsEngOnly = taskDacEngOnly * t.hours;
      maxDacHrsEngOnly = maxDacHrsEngOnly > dacHrsEngOnly ? maxDacHrsEngOnly : dacHrsEngOnly;
    }

    // derive individual trigger booleans similar to the original HTML logic
    final alara2 = totalIndividualEffectiveDose > 500;
    final alara3 = totalIndividualExtremityDose > 5000;
    final alara4 = totalCollectiveDose > 750;
    final alara5 = maxDacHrsEngOnly > 200 || maxDacSpikeEngOnly > 1000;
    final alara6 = maxContamination > 1;
    final alara8 = maxDoseRate > 10000;

    // calculate internal-only totals for alara7
    double totalInternalDoseOnly = 0.0;
    for (final t in tasks) {
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      final individualInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
      totalInternalDoseOnly += individualInternal;
    }
    final alara7 = totalInternalDoseOnly > 100;

  // Do not auto-check 'Non-routine or complex work' — user should decide this.
  final alara1 = false;

    final sampling1 = maxDacHrsWithResp > 40;
    final sampling2 = tasks.any((t) => t.pfr > 1);
    final sampling3 = false; // subjective, left for user to check
    final sampling4 = tasks.any((t) {
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      final individualInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
      return individualInternal > 500;
    });
    final condition1 = (maxDacHrsEngOnly / 40) > 0.3;
    final condition2 = maxDacSpikeEngOnly > 1.0;
    final sampling5 = condition1 || condition2;
    final sampling7 = sampling5;
    final sampling6 = false; // subjective job-based triggers left unchecked automatically

    final camsRequired = maxDacHrsWithResp > 40;

    // Aggregate some higher-level flags used by the UI
    final alaraReview = alara1 || alara2 || alara3 || alara4 || alara5 || alara6 || alara7 || alara8;
    final airSampling = sampling1 || sampling2 || sampling3 || sampling4 || sampling5 || sampling6 || sampling7;

    return {
      'alara1': alara1,
      'alara2': alara2,
      'alara3': alara3,
      'alara4': alara4,
      'alara5': alara5,
      'alara6': alara6,
      'alara7': alara7,
      'alara8': alara8,
      'sampling1': sampling1,
      'sampling2': sampling2,
      'sampling3': sampling3,
      'sampling4': sampling4,
      'sampling5': sampling5,
      'sampling6': sampling6,
      'sampling7': sampling7,
      'camsRequired': camsRequired,
      'alaraReview': alaraReview,
      'airSampling': airSampling,
      'totalIndividualEffectiveDose': totalIndividualEffectiveDose,
      'totalIndividualExtremityDose': totalIndividualExtremityDose,
      'totalCollectiveDose': totalCollectiveDose,
    };
  }

  // Get final trigger states considering both computed triggers and manual overrides
  Map<String, bool> getFinalTriggerStates() {
    final computedTriggersMap = computeGlobalTriggers();
    final finalStates = <String, bool>{};

    // Individual triggers
    for (final key in ['sampling1', 'sampling2', 'sampling3', 'sampling4', 'sampling5', 'camsRequired',
                       'alara1', 'alara2', 'alara3', 'alara4', 'alara5', 'alara6', 'alara7', 'alara8']) {
      if (computedTriggers.contains(key)) {
        // For computed triggers, use override if present, otherwise use computed value
        finalStates[key] = triggerOverrides.containsKey(key)
            ? triggerOverrides[key]!
            : (computedTriggersMap[key] ?? false);
      } else {
        // For manual triggers, use override value (defaulting to false if not set)
        finalStates[key] = triggerOverrides[key] ?? false;
      }
    }

    // Aggregate triggers based on final individual trigger states
    finalStates['airSampling'] = finalStates['sampling1']! || finalStates['sampling2']! ||
                                 finalStates['sampling3']! || finalStates['sampling4']! || finalStates['sampling5']!;
    finalStates['alaraReview'] = finalStates['alara1']! || finalStates['alara2']! || finalStates['alara3']! ||
                                finalStates['alara4']! || finalStates['alara5']! || finalStates['alara6']! ||
                                finalStates['alara7']! || finalStates['alara8']!;

    return finalStates;
  }

  // Define which triggers are computed automatically vs manual
  static const Set<String> computedTriggers = {
    'sampling1',    // Worker likely to exceed 40 DAC-hours per year (calculated)
    'sampling2',    // Respiratory protection prescribed (calculated)
    'sampling4',    // Estimated intake > 10% ALI or 500 mrem (calculated)
    'sampling5',    // Airborne concentration > 0.3 DAC (calculated)
    'camsRequired', // CAMs required (calculated)
    'alara2',       // Individual total effective dose > 500 mrem (calculated)
    'alara3',       // Individual extremity/skin dose > 5000 mrem (calculated)
    'alara4',       // Collective dose > 750 person-mrem (calculated)
    'alara5',       // Airborne >200 DAC averaged over 1 hr (calculated)
    'alara6',       // Removable contamination > 1000x Appendix D (calculated)
    'alara7',       // Worker likely to receive internal dose >100 mrem (calculated)
    'alara8',       // Entry into areas with dose rates > 10 rem/hr (calculated)
  };

  // Manual triggers that don't require justification:
  // 'sampling3' - Air sample needed to estimate internal dose (subjective)
  // 'alara1' - Non-routine or complex work (subjective)

  // Handle trigger override with justification requirement
  void handleTriggerOverride(String triggerKey, bool? newValue) async {
    if (newValue == null) return;

    // For manual triggers, just set the value directly without justification
    if (!computedTriggers.contains(triggerKey)) {
      setState(() {
        if (newValue) {
          triggerOverrides[triggerKey] = newValue;
        } else {
          triggerOverrides.remove(triggerKey);
        }
      });
      return;
    }

    final computedTriggersMap = computeGlobalTriggers();
    final computedValue = computedTriggersMap[triggerKey] ?? false;

    // If user is trying to override a computed trigger, require justification
    if (computedValue != newValue) {
      final justification = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Override Justification Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are overriding an automatically calculated trigger.'),
              SizedBox(height: 8),
              Text('Computed value: ${computedValue ? "Required" : "Not Required"}'),
              Text('Override value: ${newValue ? "Required" : "Not Required"}'),
              SizedBox(height: 16),
              Text('Please provide justification for this override:'),
              SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter justification...',
                ),
                onChanged: (text) => _tempJustification = text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _tempJustification),
              child: Text('Override'),
            ),
          ],
        ),
      );

      if (justification != null && justification.isNotEmpty) {
        setState(() {
          triggerOverrides[triggerKey] = newValue;
          overrideJustifications[triggerKey] = justification;
        });
      }
    } else {
      // If setting back to computed value, remove override
      setState(() {
        triggerOverrides.remove(triggerKey);
        overrideJustifications.remove(triggerKey);
      });
    }
  }

  String _tempJustification = '';

  // Return short textual reasons for why each trigger was set (task numbers and brief reason)
  Map<String, String> computeTriggerReasons() {
    final reasons = <String, String>{};
    if (tasks.isEmpty) return reasons;

    // Check for sampling1/cams (DAC-hrs > 40 with resp protection taken into account)
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      // compute per-nuclide DAC fraction with both protections
      double taskDacWithResp = 0.0;
      double taskDacEngOnly = 0.0;
      for (final n in t.nuclides) {
        final contam = n.contam;
        final dac = getDAC(n);
        final mPIF = computeMPIF(t);
        final airConc = (contam / 100) * mPIF * (1 / 100) * (1 / 2.22e6);
        final dacWithBoth = (airConc / dac) / (t.pfe * t.pfr);
        final dacEngOnly = (airConc / dac) / t.pfe;
        taskDacWithResp += dacWithBoth;
        taskDacEngOnly += dacEngOnly;
      }
      final dacHrsWithResp = taskDacWithResp * t.hours;
      final dacHrsEngOnly = taskDacEngOnly * t.hours;

      if (dacHrsWithResp > 40) {
        reasons['sampling1'] = 'Task ${i + 1} (> ${dacHrsWithResp.toStringAsFixed(2)} DAC-hrs)';
        reasons['camsRequired'] = 'Task ${i + 1} (> ${dacHrsWithResp.toStringAsFixed(2)} DAC-hrs)';
      }
      if (dacHrsEngOnly / 40 > 0.3) {
        reasons['sampling5'] = 'Task ${i + 1} (avg ${ (dacHrsEngOnly/40).toStringAsFixed(2)} DAC)';
      }
      if (taskDacEngOnly > 1.0) {
        reasons['sampling5'] = (reasons['sampling5'] ?? '') + ' spike by Task ${i + 1}';
      }

      // alara triggers
      if ((totals['individualEffective'] ?? 0) > 500) reasons['alara2'] = 'Task ${i + 1} individual effective > 500 mrem';
      if (t.workers > 0 && (totals['totalExtremityDose'] ?? 0) / t.workers > 5000) reasons['alara3'] = 'Task ${i + 1} extremity > 5000 mrem';
      if ((totals['collectiveEffective'] ?? 0) > 750) reasons['alara4'] = 'Task ${i + 1} collective > 750 mrem';
      if (taskDacEngOnly * t.hours > 200) reasons['alara5'] = 'Task ${i + 1} DAC-hrs eng-only > 200';
      if (t.nuclides.any((n) => n.contam / 1000 > 1)) reasons['alara6'] = 'Task ${i + 1} contamination > 1000x Appendix D';
      if (t.workers > 0 && (totals['collectiveInternal'] ?? 0) / t.workers > 100) reasons['alara7'] = 'Task ${i + 1} internal > 100 mrem';
      if (t.doseRate > 10000) reasons['alara8'] = 'Task ${i + 1} dose rate > 10 rem/hr';
    }

    return reasons;
  }

  void saveToFile() async {
    if (kIsWeb) {
      // For web, trigger file download
      final state = {
        'projectInfo': {
          'workOrder': workOrderController.text,
          'date': dateController.text,
          'description': descriptionController.text,
        },
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'triggerOverrides': triggerOverrides,
        'overrideJustifications': overrideJustifications,
      };
      final jsonStr = jsonEncode(state);
      final bytes = utf8.encode(jsonStr);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'dose_assessment_${DateTime.now().millisecondsSinceEpoch}.json';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File downloaded successfully.')));
      return;
    }

    try {
      final state = {
        'projectInfo': {
          'workOrder': workOrderController.text,
          'date': dateController.text,
          'description': descriptionController.text,
        },
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'triggerOverrides': triggerOverrides,
        'overrideJustifications': overrideJustifications,
      };
      final jsonStr = jsonEncode(state);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save dose assessment',
        fileName: 'dose_assessment.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonStr);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File saved successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
    }
  }


  void loadFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        String fileContent;
        if (kIsWeb) {
          // For web, read from bytes
          final bytes = result.files.single.bytes!;
          fileContent = utf8.decode(bytes);
        } else {
          // For desktop/mobile, read from file path
          final file = File(result.files.single.path!);
          fileContent = await file.readAsString();
        }

        final Map<String, dynamic> state = jsonDecode(fileContent);

        setState(() {
          workOrderController.text = state['projectInfo']?['workOrder'] ?? '';
          dateController.text = state['projectInfo']?['date'] ?? '';
          descriptionController.text = state['projectInfo']?['description'] ?? '';
          // dispose existing task controllers first
          for (final tt in tasks) {
            tt.disposeControllers();
          }
          tasks = (state['tasks'] as List? ?? []).map((t) => TaskData.fromJson(t)).toList();
          // load trigger overrides if present
          triggerOverrides = Map<String, bool>.from(state['triggerOverrides'] ?? {});
          overrideJustifications = Map<String, String>.from(state['overrideJustifications'] ?? {});
          tabController = TabController(length: tasks.length + 1, vsync: this);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File loaded successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load file: $e')));
    }
  }

  Future<void> printSummaryReport() async {
    try {
      final pdf = pw.Document();

      // Calculate all summary data
      final computedTriggers = computeGlobalTriggers();
      final finalTriggers = getFinalTriggerStates();

      double totalIndividualEffective = 0.0;
      double totalIndividualExtremity = 0.0;
      double totalCollectiveExternal = 0.0;
      double totalCollectiveInternal = 0.0;

      final List<Map<String, dynamic>> taskSummaries = [];

      for (final t in tasks) {
        final totals = calculateTaskTotals(t);
        final workers = t.workers;
        final individualExternal = workers > 0 ? (totals['collectiveExternal']! / workers) : 0.0;
        final individualInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
        final individualExtremity = workers > 0 ? (totals['totalExtremityDose']! / workers) : 0.0;
        final individualTotal = individualExternal + individualInternal;

        totalCollectiveExternal += totals['collectiveExternal']!;
        totalCollectiveInternal += totals['collectiveInternal']!;
        totalIndividualEffective += individualTotal;
        totalIndividualExtremity += individualExtremity;

        taskSummaries.add({
          'task': t,
          'totals': totals,
          'individualExternal': individualExternal,
          'individualInternal': individualInternal,
          'individualExtremity': individualExtremity,
          'individualTotal': individualTotal,
        });
      }

      final totalCollective = totalCollectiveExternal + totalCollectiveInternal;

      // Page 1: Quick Overview Summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 20),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 2)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RPP-742 Task-Based Dose Assessment',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('Work Order: ${workOrderController.text}', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Date: ${dateController.text}', style: const pw.TextStyle(fontSize: 12)),
                      if (descriptionController.text.isNotEmpty)
                        pw.Text('Description: ${descriptionController.text}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Trigger Indicators
                pw.Text('Trigger Indicators', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 15,
                            height: 15,
                            decoration: pw.BoxDecoration(
                              color: finalTriggers['alaraReview'] == true
                                  ? PdfColors.red
                                  : PdfColors.green,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text('ALARA Review', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 15,
                            height: 15,
                            decoration: pw.BoxDecoration(
                              color: finalTriggers['airSampling'] == true
                                  ? PdfColors.red
                                  : PdfColors.green,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text('Air Sampling', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 15,
                            height: 15,
                            decoration: pw.BoxDecoration(
                              color: finalTriggers['cams'] == true
                                  ? PdfColors.red
                                  : PdfColors.green,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text('CAMs', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Overall Dose Summary
                pw.Text('Overall Dose Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Collective Dose: ${totalCollective.toStringAsFixed(2)} person-mrem',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('  External: ${totalCollectiveExternal.toStringAsFixed(2)} person-mrem',
                          style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('  Internal: ${formatNumber(totalCollectiveInternal)} person-mrem',
                          style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 8),
                      pw.Text('Total Extremity Dose: ${(totalIndividualExtremity * (tasks.isNotEmpty ? tasks.first.workers : 1)).toStringAsFixed(2)} mrem',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Task Summary Table
                pw.Text('Task Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Task', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Location', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Ind. Ext.\n(mrem)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Ind. Int.\n(mrem)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Total Ind.\n(mrem)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...taskSummaries.map((summary) {
                      final t = summary['task'] as TaskData;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t.title, style: const pw.TextStyle(fontSize: 9), softWrap: true),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t.location, style: const pw.TextStyle(fontSize: 9), softWrap: true),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(summary['individualExternal'].toStringAsFixed(2),
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(formatNumber(summary['individualInternal']),
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(summary['individualTotal'].toStringAsFixed(2),
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Page 2+: Detailed Task Data
      for (var i = 0; i < taskSummaries.length; i++) {
        final summary = taskSummaries[i];
        final t = summary['task'] as TaskData;
        final totals = summary['totals'] as Map<String, double>;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Task Header
                  pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 2)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Task ${i + 1}: ${t.title}',
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                            softWrap: true,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'Page ${i + 2}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Task Details
                  pw.Text('Task Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(child: pw.Text('Location: ${t.location}', style: const pw.TextStyle(fontSize: 10))),
                            pw.Expanded(child: pw.Text('Workers: ${t.workers}', style: const pw.TextStyle(fontSize: 10))),
                            pw.Expanded(child: pw.Text('Hours: ${t.hours}', style: const pw.TextStyle(fontSize: 10))),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Expanded(child: pw.Text('External Dose Rate: ${t.doseRate} mrem/hr', style: const pw.TextStyle(fontSize: 10))),
                            pw.Expanded(child: pw.Text('PFR: ${t.pfr}', style: const pw.TextStyle(fontSize: 10))),
                            pw.Expanded(child: pw.Text('PFE: ${t.pfe}', style: const pw.TextStyle(fontSize: 10))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Material Protection Factors
                  pw.Text('Material Protection Factors', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'R: ${t.mpifR}  C: ${t.mpifC}  D: ${t.mpifD}  S: ${t.mpifS}  U: ${t.mpifU}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Nuclide Information
                  if (t.nuclides.isNotEmpty) ...[
                    pw.Text('Nuclide Contamination', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Nuclide', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Contamination\n(dpm/100cm²)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('DAC Fraction', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...t.nuclides.map((n) {
                          final res = computeNuclideDose(n, t);
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(n.name, style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(formatNumber(n.contam), style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(formatNumber(res['dacFractionEngOnly']!), style: const pw.TextStyle(fontSize: 9)),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                  ],

                  // Extremity Information
                  if (t.extremities.isNotEmpty) ...[
                    pw.Text('Extremity Exposure', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Nuclide', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Dose Rate\n(mrem/hr)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Time\n(hours)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Total\n(mrem)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...t.extremities.map((e) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(e.nuclide ?? '', style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(e.doseRate.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(e.time.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text((e.doseRate * e.time).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                  ],

                  // Dose Summary for this Task
                  pw.Text('Dose Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Individual Doses:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('  External: ${summary['individualExternal'].toStringAsFixed(2)} mrem', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('  Internal: ${formatNumber(summary['individualInternal'])} mrem', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('  Extremity: ${summary['individualExtremity'].toStringAsFixed(2)} mrem', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('  Total Effective: ${summary['individualTotal'].toStringAsFixed(2)} mrem',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text('Collective Doses:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('  External: ${totals['collectiveExternal']!.toStringAsFixed(2)} person-mrem', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('  Internal: ${formatNumber(totals['collectiveInternal']!)} person-mrem', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('  Total Effective: ${totals['collectiveEffective']!.toStringAsFixed(2)} person-mrem',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print dialog opened')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    }
  }


  Widget buildSummary() {
    double totalIndividualEffective = 0.0;
    double totalIndividualExtremity = 0.0;
    double totalCollectiveExternal = 0.0;
    double totalCollectiveInternal = 0.0;
    final rows = <TableRow>[];
    final computedTriggers = computeGlobalTriggers();
    final finalTriggers = getFinalTriggerStates();

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 24.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.playlist_add_check, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                const Text('', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton.icon(onPressed: () { addTask(); }, icon: const Icon(Icons.add), label: const Text('Add Task'))
              ]),
            ),
          ),
        ),
      );
    }

    double totalWorkers = 0.0;
    Set<int> workerCounts = {};

    for (final t in tasks) {
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      workerCounts.add(workers);
      totalWorkers += workers;

      final individualExternal = workers > 0 ? (totals['collectiveExternal']! / workers) : 0.0;
      final individualInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
      totalCollectiveExternal += totals['collectiveExternal']!;
      totalCollectiveInternal += totals['collectiveInternal']!;
      final individualTotal = individualExternal + individualInternal;
      totalIndividualEffective += individualTotal;
      totalIndividualExtremity += totals['totalExtremityDose']! / (workers);

      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(t.title)),
        Padding(padding: const EdgeInsets.all(8), child: Text(t.location)),
        Padding(padding: const EdgeInsets.all(8), child: Text('${t.workers}')),
  Padding(padding: const EdgeInsets.all(8), child: Text(formatNumber(totals['totalDacFraction']!))),
        Padding(padding: const EdgeInsets.all(8), child: Text(individualExternal.toStringAsFixed(2))),
  Padding(padding: const EdgeInsets.all(8), child: Text(formatNumber(individualInternal))),
        Padding(padding: const EdgeInsets.all(8), child: Text((workers > 0 ? (totals['totalExtremityDose']! / workers) : 0.0).toStringAsFixed(2))),
        Padding(padding: const EdgeInsets.all(8), child: Text(totals['collectiveExternal']!.toStringAsFixed(2))),
  Padding(padding: const EdgeInsets.all(8), child: Text(formatNumber(totals['collectiveInternal']!))),
        Padding(padding: const EdgeInsets.all(8), child: Text(individualTotal.toStringAsFixed(2))),
      ]));
    }

    // Build a list of small cards for each task to show key dose numbers prominently
    final taskCards = tasks.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      final totals = calculateTaskTotals(t);
      final workers = t.workers;
      final indExternal = workers > 0 ? (totals['collectiveExternal']! / workers) : 0.0;
      final indInternal = workers > 0 ? (totals['collectiveInternal']! / workers) : 0.0;
      final indExtremity = workers > 0 ? (totals['totalExtremityDose']! / workers) : 0.0;
      final indTotal = indExternal + indInternal;

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Task ${i + 1}: ${t.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Individual External', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(indExternal.toStringAsFixed(2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Individual Internal', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(formatNumber(indInternal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Extremity Dose', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(indExtremity.toStringAsFixed(2), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Individual', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(indTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blueAccent)),
              ]),
            ])
          ]),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detailed triggers section first
        buildTriggers(),
        const SizedBox(height: 12),

        // ALARA/Air Sampling/CAMs indicator cards second
        Row(children: [
          Expanded(child: Card(
            color: finalTriggers['alaraReview'] == true ? Colors.red.shade50 : Colors.grey.shade100,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Icon(
                    finalTriggers['alaraReview'] == true ? Icons.check_circle : Icons.close,
                    color: finalTriggers['alaraReview'] == true ? Colors.red : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ALARA Review',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: finalTriggers['alaraReview'] == true ? Colors.red.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    finalTriggers['alaraReview'] == true ? 'Required' : 'Not Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: finalTriggers['alaraReview'] == true ? Colors.red.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: Card(
            color: finalTriggers['airSampling'] == true ? Colors.red.shade50 : Colors.grey.shade100,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Icon(
                    finalTriggers['airSampling'] == true ? Icons.check_circle : Icons.close,
                    color: finalTriggers['airSampling'] == true ? Colors.red : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Air Sampling',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: finalTriggers['airSampling'] == true ? Colors.red.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    finalTriggers['airSampling'] == true ? 'Required' : 'Not Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: finalTriggers['airSampling'] == true ? Colors.red.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: Card(
            color: finalTriggers['camsRequired'] == true ? Colors.red.shade50 : Colors.grey.shade100,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Icon(
                    finalTriggers['camsRequired'] == true ? Icons.check_circle : Icons.close,
                    color: finalTriggers['camsRequired'] == true ? Colors.red : Colors.grey.shade600,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CAMs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: finalTriggers['camsRequired'] == true ? Colors.red.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    finalTriggers['camsRequired'] == true ? 'Required' : 'Not Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: finalTriggers['camsRequired'] == true ? Colors.red.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )),
        ]),
        const SizedBox(height: 16),

        // Task summary cards with enhanced styling
        if (taskCards.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Individual Task Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  const SizedBox(width: 4),
                  ...taskCards.map((c) => Padding(padding: const EdgeInsets.only(right: 12.0), child: c)),
                  const SizedBox(width: 4),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Overall dose summary last with enhanced design
        Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Overall Dose Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              // Main Collective Dose Card with breakdown
              Expanded(
                flex: 2,
                child: Card(
                  color: Colors.purple.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main title
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'TOTAL COLLECTIVE DOSE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Total value
                        Text(
                          '${(totalCollectiveExternal + totalCollectiveInternal).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.purple),
                        ),
                        const SizedBox(height: 4),
                        const Text('person-mrem', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        // Breakdown cards
                        Row(children: [
                          Expanded(child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('EXTERNAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                const SizedBox(height: 4),
                                Text('${totalCollectiveExternal.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                              ],
                            ),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('INTERNAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                                const SizedBox(height: 4),
                                Text(formatNumber(totalCollectiveInternal), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                              ],
                            ),
                          )),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Extremity Dose Card
              Expanded(
                flex: 1,
                child: Card(
                  color: Colors.orange.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'EXTREMITY DOSE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${tasks.fold<double>(0, (sum, t) => sum + calculateTaskTotals(t)['totalExtremityDose']!).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        const Text('person-mrem', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[const Tab(text: 'Summary')];
    tabs.addAll(List.generate(tasks.length, (i) {
      final td = tasks[i];
      // Show the task number before the title. If no title, show just the number.
      final label = (td.title.trim().isEmpty) ? '${i + 1}' : '${i + 1} ${td.title}';
      return Tab(key: ValueKey('task-tab-$i'), text: label);
    }));

    return Scaffold(
      appBar: AppBar(
        title: const Text('RPP-742 Task-Based Dose Assessment'),
        actions: [
          IconButton(onPressed: saveToFile, icon: const Icon(Icons.save)),
          IconButton(onPressed: loadFromFile, icon: const Icon(Icons.folder_open)),
          IconButton(onPressed: printSummaryReport, icon: const Icon(Icons.print)),
          IconButton(onPressed: () {
            // Diagnostic dialog: show per-nuclide computed fields for the first task (or a sample)
            final t = tasks.isNotEmpty ? tasks.first : TaskData(title: 'Sample', location: 'Lab', workers: 1, hours: 15.0, mpifR: 1.0, mpifC: 100.0, mpifD: 1.0, mpifS: 1.0, mpifU: 1.0, doseRate: 0.0, pfr: 1.0, pfe: 1.0, nuclides: [NuclideEntry(name: 'Sr-90', contam: 100000.0)]);
            final List<Widget> rows = [];
            rows.add(Text('Task: ${t.title}  Location: ${t.location}'));
            rows.add(const SizedBox(height: 8));
            for (final n in t.nuclides) {
              final res = computeNuclideDose(n, t);
              final dac = res['dac'] ?? 0.0;
              final airConc = res['airConc'] ?? 0.0;
              final raw = res['dacFractionRaw'] ?? 0.0;
              final eng = res['dacFractionEngOnly'] ?? 0.0;
              final collective = res['collective'] ?? 0.0;
              final individual = res['individual'] ?? 0.0;
              rows.add(Text('Nuclide: ${n.name}  Contam: ${n.contam} dpm/100cm²'));
              rows.add(Text('  DAC: ${formatNumber(dac)}'));
              rows.add(Text('  Air conc: ${airConc.toStringAsExponential(6)}'));
              rows.add(Text('  DAC fraction (raw): ${raw.toStringAsExponential(6)}'));
              rows.add(Text('  DAC fraction (after PFE): ${eng.toStringAsExponential(6)}'));
              rows.add(Text('  Collective internal dose: ${collective.toStringAsExponential(6)}'));
              rows.add(Text('  Individual internal dose: ${individual.toStringAsExponential(6)}'));
              rows.add(const SizedBox(height: 6));
            }
            showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Per-nuclide Diagnostics'), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: rows)), actions: [TextButton(onPressed: () { Navigator.of(ctx).pop(); }, child: const Text('Close'))]));
          }, icon: const Icon(Icons.bug_report)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Enhanced Project Info card with modern styling to match result cards
            Container(
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: workOrderController,
                    decoration: InputDecoration(
                      labelText: 'Work Control Document Number',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                    ),
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today, color: Colors.blueGrey.shade600),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                    ),
                    readOnly: true,
                    style: TextStyle(color: Colors.blueGrey.shade700),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        dateController.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Work Description',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blueGrey.shade300),
                      ),
                    ),
                    maxLines: 3,
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Triggers moved into the Summary tab only

            // Tab area centered inside a rounded Card with lively accents
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha((0.08*255).round())),
                boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Inner elevated TabBar with rounded, raised indicator
                      Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: PhysicalModel(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          // Pill slider container with background and animated indicator
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Stack(
                              children: [
                                // Animated pill indicator
                                AnimatedBuilder(
                                  animation: tabController,
                                  builder: (context, child) {
                                    final selectedIndex = tabController.index;
                                    const tabWidth = 160.0; // Fixed width for consistent sliding
                                    const tabSpacing = 4.0;

                                    return AnimatedPositioned(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      left: selectedIndex * (tabWidth + tabSpacing),
                                      child: Container(
                                        width: tabWidth,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          // Translucent glassy effect
                                          color: selectedIndex == 0
                                            ? Colors.indigo.shade200.withOpacity(0.4)
                                            : Colors.blue.shade200.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selectedIndex == 0
                                              ? Colors.indigo.shade300.withOpacity(0.6)
                                              : Colors.blue.shade300.withOpacity(0.6),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (selectedIndex == 0 ? Colors.indigo : Colors.blue).withOpacity(0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Tab buttons on top of the slider
                                Row(
                                  children: List.generate(tabs.length, (index) {
                                    final isSelected = tabController.index == index;
                                    const tabWidth = 160.0;

                                    return Container(
                                      width: tabWidth,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 4),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () {
                                            tabController.animateTo(index);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Center(
                                              child: Text(
                                                tabs[index].text ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                    ? (index == 0 ? Colors.indigo.shade800 : Colors.blue.shade800)
                                                    : Colors.grey.shade700,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Enhanced Add Task button with card styling
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                addTask();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  try {
                                    tabController.animateTo(tasks.length);
                                  } catch (_) {}
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2)
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add Task',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      // Summary tab — emphasized summary card
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(padding: const EdgeInsets.all(12), child: buildSummary()),
                        ),
                      ),
                      // Task tabs
                      for (var i = 0; i < tasks.length; i++) KeyedSubtree(key: ValueKey('task-view-$i'), child: buildTaskTab(i)),
                    ],
                  ),
                )
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTriggers() {
    final computedTriggers = computeGlobalTriggers();
    final finalTriggers = getFinalTriggerStates();
    final reasons = computeTriggerReasons();
    // Build ALARA card and Air Sampling card similar to original HTML checklist
    return Column(children: [
      Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Workplace Air Sampling Triggers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: finalTriggers['sampling1'] ?? false,
              onChanged: (v) { handleTriggerOverride('sampling1', v); },
              title: const Text('Worker likely to exceed 40 DAC-hours per year (air sampling required)'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('sampling1')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['sampling1']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('sampling1')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['sampling1']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(
              value: finalTriggers['sampling2'] ?? false,
              onChanged: (v) { handleTriggerOverride('sampling2', v); },
              title: const Text('Respiratory protection prescribed (air sampling required)'), controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('sampling2')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['sampling2']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('sampling2')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['sampling2']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(
              value: finalTriggers['sampling3'] ?? false,
              onChanged: (v) { handleTriggerOverride('sampling3', v); },
              title: const Text('Air sample needed to estimate internal dose'), controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('sampling3')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['sampling3']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('sampling3')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['sampling3']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(
              value: finalTriggers['sampling4'] ?? false,
              onChanged: (v) { handleTriggerOverride('sampling4', v); },
              title: const Text('Estimated intake > 10% ALI or 500 mrem'), controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('sampling4')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['sampling4']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('sampling4')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['sampling4']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(
              value: finalTriggers['sampling5'] ?? false,
              onChanged: (v) { handleTriggerOverride('sampling5', v); },
              title: const Text('Airborne concentration > 0.3 DAC averaged over 40 hr or >1 DAC spike'), controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('sampling5')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['sampling5']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('sampling5')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['sampling5']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(
              value: finalTriggers['camsRequired'] ?? false,
              onChanged: (v) { handleTriggerOverride('camsRequired', v); },
              title: const Text('CAMs required (worker > 40 DAC-hrs in week)'), controlAffinity: ListTileControlAffinity.leading,
            ),
            if (reasons.containsKey('camsRequired')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['camsRequired']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('camsRequired')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['camsRequired']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ALARA Trigger Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(value: finalTriggers['alara1'] ?? false, onChanged: (v) { handleTriggerOverride('alara1', v); }, title: const Text('Non-routine or complex work'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara1')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara1']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara1')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara1']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara2'] ?? false, onChanged: (v) { handleTriggerOverride('alara2', v); }, title: const Text('Estimated individual total effective dose > 500 mrem'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara2')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara2']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara2')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara2']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara3'] ?? false, onChanged: (v) { handleTriggerOverride('alara3', v); }, title: const Text('Estimated individual extremity/skin dose > 5000 mrem'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara3')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara3']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara3')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara3']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara4'] ?? false, onChanged: (v) { handleTriggerOverride('alara4', v); }, title: const Text('Collective dose > 750 person-mrem'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara4')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara4']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara4')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara4']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara5'] ?? false, onChanged: (v) { handleTriggerOverride('alara5', v); }, title: const Text('Airborne >200 DAC averaged over 1 hr or spike >1000 DAC'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara5')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara5']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara5')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara5']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara6'] ?? false, onChanged: (v) { handleTriggerOverride('alara6', v); }, title: const Text('Removable contamination > 1000x Appendix D levels'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara6')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara6']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara6')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara6']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara7'] ?? false, onChanged: (v) { handleTriggerOverride('alara7', v); }, title: const Text('Worker likely to receive internal dose >100 mrem'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara7')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara7']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara7')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara7']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
            CheckboxListTile(value: finalTriggers['alara8'] ?? false, onChanged: (v) { handleTriggerOverride('alara8', v); }, title: const Text('Entry into areas with dose rates > 10 rem/hr at 30 cm'), controlAffinity: ListTileControlAffinity.leading),
            if (reasons.containsKey('alara8')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text(reasons['alara8']!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            if (overrideJustifications.containsKey('alara8')) Padding(padding: const EdgeInsets.only(left: 56.0, bottom: 8.0), child: Text('Override: ${overrideJustifications['alara8']!}', style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic))),
          ]),
        ),
      ),
    ]);
  }

  Widget buildTaskTab(int index) {
    final t = tasks[index];
    final totals = calculateTaskTotals(t);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    controller: t.titleController,
                    focusNode: t.titleFocusNode,
                    autofocus: t.titleController.text.isEmpty,
                    onChanged: (v) { setState(() {}); }
                  )),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: () => removeTask(index), icon: const Icon(Icons.delete), label: const Text('Remove Task'))
                ]),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Location',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  controller: t.locationController,
                  onChanged: (v) { setState(() {}); }
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Time Estimation
          Card(
            child: ExpansionTile(title: const Text('Time Estimation'), initiallyExpanded: true, children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: TextField(
                      decoration: InputDecoration(
                        labelText: '# Workers',
                        hintText: 'Enter number of workers',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      controller: t.workersController,
                      onChanged: (v) { setState(() {}); }
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Hours Each',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: t.hoursController,
                      onChanged: (v) { setState(() {}); }
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Card(
                      color: Colors.blue.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Person-Hours', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text('${calculateTaskTotals(t)['personHours']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ))
                  ])
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          Card(
            child: ExpansionTile(title: const Text('mPIF Calculation'), children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<double>(
                      value: t.mpifR > 0.0 ? t.mpifR : null,
                      decoration: InputDecoration(
                        labelText: 'Release Factor (R)',
                        hintText: 'Select R',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: releaseFactors.entries.map((e) => DropdownMenuItem(value: e.value, child: Text('${e.key}'))).toList(),
                      onChanged: (v) { t.mpifR = v ?? 0.0; setState(() {}); }
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<double>(
                      value: t.mpifC > 0.0 ? t.mpifC : null,
                      decoration: InputDecoration(
                        labelText: 'Confinement Factor (C)',
                        hintText: 'Select C',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: confinementFactors.entries.map((e) => DropdownMenuItem(value: e.value, child: Text('${e.key}'))).toList(),
                      onChanged: (v) { t.mpifC = v ?? 0.0; setState(() {}); }
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    // Dispersibility dropdown 1..10
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: (t.mpifD > 0.0) ? t.mpifD.toInt() : null,
                        decoration: InputDecoration(
                          labelText: 'Dispersibility (D)',
                          hintText: 'Select D',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: List.generate(10, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            t.mpifD = v.toDouble();
                            t.mpifDController.text = v.toString();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Uncertainty dropdown 1..10
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: (t.mpifU > 0.0) ? t.mpifU.toInt() : null,
                        decoration: InputDecoration(
                          labelText: 'Uncertainty (U)',
                          hintText: 'Select U',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: List.generate(10, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            t.mpifU = v.toDouble();
                            t.mpifUController.text = v.toString();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Special Form dropdown (placed last in row)
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        value: (t.mpifS > 0.0) ? t.mpifS : null,
                        decoration: InputDecoration(
                          labelText: 'Special Form (S)',
                          hintText: 'Select S',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: [0.1, 1.0].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            t.mpifS = v;
                            t.mpifSController.text = v.toString();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Card(
                      color: Colors.purple.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('mPIF Result', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Tooltip(
                              message: 'mPIF = 1e-6 * R * C * D * S * U',
                              child: Text(
                                calculateTaskTotals(t)['mPIF']! > 0.0 ? '${calculateTaskTotals(t)['mPIF']!.toStringAsExponential(2)}' : '(not set)',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                  ])
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          Card(
            child: ExpansionTile(title: const Text('External Dose Estimate'), children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Column(children: [
                    Row(children: [
                      Expanded(child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Dose Rate (mrem/hr)',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        controller: t.doseRateController,
                        onChanged: (v) { setState(() {}); }
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: Card(
                        color: Colors.green.shade50,
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Person-Hours', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Text('${totals['personHours']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Card(
                        color: Colors.orange.shade50,
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Collective External', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),
                              Text('${totals['collectiveExternal']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              const SizedBox(height: 2),
                              const Text('(mrem)', style: TextStyle(fontSize: 10, color: Colors.black45)),
                            ],
                          ),
                        ),
                      )),
                    ]),
                  ])
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          Card(
            child: ExpansionTile(title: const Text('Extremity/Skin Dose Estimate'), children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Column(children: List.generate(t.extremities.length, (ei) {
                    final e = t.extremities[ei];
                    return Row(children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') return dacValues.keys.toList();
                              return dacValues.keys.where((k) => k.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            onSelected: (selection) { e.nuclide = selection; setState(() {}); },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              controller.text = e.nuclide ?? '';
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Select a radionuclide',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                )
                              );
                            },
                          ),
                        ),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Dose Rate (mrem/hr)',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      controller: e.doseRateController,
                      onChanged: (v) { setState(() { e.doseRate = double.tryParse(v) ?? 0.0; }); }
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Time (hr)',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      controller: e.timeController,
                      onChanged: (v) { setState(() { e.time = double.tryParse(v) ?? 0.0; }); }
                    )),
                    IconButton(onPressed: () { setState(() { e.disposeControllers(); t.extremities.removeAt(ei); }); }, icon: const Icon(Icons.delete, color: Colors.red)),
                  ]);
                  })),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: () { setState(() { t.extremities.add(ExtremityEntry()); }); }, icon: const Icon(Icons.add), label: const Text('Add Extremity Dose')),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Card(
                      color: Colors.deepOrange.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Individual Extremity Dose', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text('${totals['individualExtremity']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            const SizedBox(height: 2),
                            const Text('(mrem per person)', style: TextStyle(fontSize: 10, color: Colors.black45)),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Card(
                      color: Colors.red.shade50,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Collective Extremity Dose', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text('${totals['collectiveExtremity']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 2),
                            const Text('(mrem)', style: TextStyle(fontSize: 10, color: Colors.black45)),
                          ],
                        ),
                      ),
                    )),
                  ])
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          Card(
            child: ExpansionTile(title: const Text('Protection Factors'), children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Respiratory (PFR)'),
                    RadioListTile<double>(value: 1.0, groupValue: t.pfr, title: const Text('None (PFR=1)'), onChanged: (v) { t.pfr = v ?? t.pfr; setState(() {}); }),
                    RadioListTile<double>(value: 50.0, groupValue: t.pfr, title: const Text('APR (PFR=50)'), onChanged: (v) { t.pfr = v ?? t.pfr; setState(() {}); }),
                    RadioListTile<double>(value: 1000.0, groupValue: t.pfr, title: const Text('PAPR (PFR=1000)'), onChanged: (v) { t.pfr = v ?? t.pfr; setState(() {}); }),
                    const SizedBox(height: 6),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Engineering (PFE)'),
                    RadioListTile<double>(value: 1.0, groupValue: t.pfe, title: const Text('No Controls (PFE=1)'), onChanged: (v) { t.pfe = v ?? t.pfe; setState(() {}); }),
                    RadioListTile<double>(value: 1000.0, groupValue: t.pfe, title: const Text('Type I (PFE=1,000)'), onChanged: (v) { t.pfe = v ?? t.pfe; setState(() {}); }),
                    RadioListTile<double>(value: 100000.0, groupValue: t.pfe, title: const Text('Type II (PFE=100,000)'), onChanged: (v) { t.pfe = v ?? t.pfe; setState(() {}); }),
                    const SizedBox(height: 6),
                  ])),
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          Card(
            child: ExpansionTile(title: const Text('Internal Dose Calculation'), children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                    Column(children: List.generate(t.nuclides.length, (ni) {
                    final n = t.nuclides[ni];
                    final res = computeNuclideDose(n, t);
                    final dac = res['dac'] ?? 1e-12;
                    final airConc = res['airConc'] ?? 0.0;
                    final dacFractionEngOnly = res['dacFractionEngOnly'] ?? 0.0;
                    final nuclideCollective = res['collective'] ?? 0.0;
                    final nuclideIndividualPerPerson = res['individual'] ?? 0.0;

                    return Column(children: [
                      Row(children: [
                        Expanded(
                          child: Autocomplete<String>(
                            initialValue: TextEditingValue(text: n.name ?? ''),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') return dacValues.keys.toList();
                              return dacValues.keys.where((k) => k.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      final dac = dacValues[option] ?? 1e-12;
                                      return ListTile(
                                        title: Text(option),
                                        subtitle: option == 'Other'
                                            ? const Text('Custom DAC required')
                                            : Text('DAC: ${formatNumber(dac)}'),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            onSelected: (selection) {
                              n.name = selection;
                              // Clear custom DAC when changing from "Other" to a specific nuclide
                              if (selection != 'Other') {
                                n.customDAC = null;
                                n.dacController.clear();
                              }
                              setState(() {});
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              controller.text = n.name ?? '';
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Nuclide',
                                    hintText: 'Select a radionuclide',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  )
                                )
                              ]);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Show DAC input field when "Other" is selected
                        if (n.name == 'Other') ...[
                          Expanded(child: TextField(
                            decoration: InputDecoration(
                              labelText: 'DAC (µCi/mL)',
                              hintText: 'Required for Other',
                              filled: true,
                              fillColor: Colors.orange.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.orange.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.orange.shade300),
                              ),
                            ),
                            controller: n.dacController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              // allow digits, decimal point, exponent notation (e/E) and signs
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-\.]')),
                            ],
                            onChanged: (v) { setState(() {}); },
                          )),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: TextField(
                          decoration: const InputDecoration(labelText: 'Contam. (dpm/100cm²)', hintText: 'enter contamination level here'),
                          controller: n.contamController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            // allow digits, decimal point, exponent notation (e/E) and signs
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-\.]')),
                          ],
                          onChanged: (v) { setState(() {}); },
                        )),
                        IconButton(onPressed: () { setState(() { n.disposeControllers(); t.nuclides.removeAt(ni); }); }, icon: const Icon(Icons.delete, color: Colors.red)),
                      ]),

                      // Single concise card showing internal dose computed as:
                      // InternalDose_collective = ((airConc / (PFE * PFR)) / DAC) * (workers * hours) / 2000 * 5000
                      // InternalDose_individual = InternalDose_collective / workers
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          color: Colors.white,
                          child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Per-nuclide Details', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Airborne conc.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(airConc.isFinite ? airConc.toStringAsExponential(3) : '0', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ])),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('DAC Fraction (after PFE)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(dacFractionEngOnly.isFinite ? formatNumber(dacFractionEngOnly) : '0', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ])),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: Text('Internal Dose (per person): ${formatNumber(nuclideIndividualPerPerson)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Internal Dose (collective): ${formatNumber(nuclideCollective)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            ])
                          ])),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(),
                    ]);
                  })),
                  ElevatedButton.icon(onPressed: () { setState(() { t.nuclides.add(NuclideEntry()); }); }, icon: const Icon(Icons.add), label: const Text('Add Nuclide')),
                ]),
              )
            ]),
          ),

          const SizedBox(height: 12),

          // Prominent per-task totals displayed as three compact cards for visual emphasis
          // Task-level DAC summary card (summed DAC fraction and DAC-hours)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Summed DAC Fraction (post-PFE)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(formatNumber(totals['totalDacFraction'] ?? 0.0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('DAC-hours (post-PFE)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(formatNumber((totals['totalDacFraction'] ?? 0.0) * t.hours), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ])),
                ]),
              ),
            ),
          ),

          Row(children: [
            Expanded(
        child: Card(
          color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Collective Effective', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(totals['collectiveEffective']!.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 4),
                    Text('(mrem)', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Individual Effective', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(totals['individualEffective']!.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text('(mrem per person)', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
        child: Card(
          color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Individual Extremity', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(totals['totalExtremityDose']!.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const SizedBox(height: 4),
                    Text('(mrem per person)', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
