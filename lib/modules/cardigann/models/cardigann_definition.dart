import 'package:yaml/yaml.dart';
import 'package:kazumi/modules/cardigann/cardigann_torznab.dart';

/// Cardigann indexer definition AST, 1:1 aligned with Jackett / Prowlarr Cardigann specification.
class CardigannDefinition {
  final String id;
  final String name;
  final String description;
  final String language;
  final String type; // public, semi-private, private
  final String encoding;
  final List<String> links;
  final CardigannCaps caps;
  final List<CardigannSetting> settings;
  final CardigannLogin? login;
  final CardigannSearch search;
  final bool useWebview;
  final String rawYaml;

  const CardigannDefinition({
    required this.id,
    required this.name,
    this.description = '',
    this.language = 'en-US',
    this.type = 'public',
    this.encoding = 'UTF-8',
    this.links = const [],
    required this.caps,
    this.settings = const [],
    this.login,
    required this.search,
    this.useWebview = false,
    required this.rawYaml,
  });

  String get defaultLink => links.isNotEmpty ? links.first : '';
  bool get isPrivate => type.toLowerCase() == 'private';
  bool get isSemiPrivate => type.toLowerCase() == 'semi-private';
  bool get isPublic => type.toLowerCase() == 'public';

  /// Maps site category string or id to Torznab category number using caps.categorymappings.
  int? mapToTorznabCategory(String siteCat) {
    final clean = siteCat.trim();
    if (clean.isEmpty) return null;
    for (final mapping in caps.categorymappings) {
      if (mapping.id.toLowerCase() == clean.toLowerCase()) {
        return mapping.cat;
      }
    }
    final parsed = int.tryParse(clean);
    if (parsed != null) {
      return parsed;
    }
    final textCat = TorznabCategories.parseCategory(clean);
    if (textCat != TorznabCategories.other) {
      return textCat;
    }
    return null;
  }
}

class CardigannCaps {
  final List<CardigannCategoryMapping> categorymappings;
  final Map<String, List<String>> modes;

  const CardigannCaps({
    this.categorymappings = const [],
    this.modes = const {},
  });
}

class CardigannCategoryMapping {
  final String id;
  final int cat;
  final String desc;

  const CardigannCategoryMapping({
    required this.id,
    required this.cat,
    this.desc = '',
  });

  factory CardigannCategoryMapping.fromMap(Map<String, dynamic> map) {
    final catVal = TorznabCategories.parseCategory(map['cat']);
    return CardigannCategoryMapping(
      id: map['id']?.toString() ?? '',
      cat: catVal,
      desc: map['desc']?.toString() ?? '',
    );
  }
}

class CardigannSetting {
  final String name;
  final String type; // text, password, select, checkbox, info
  final String label;
  final dynamic defaultValue;
  final Map<String, String> options;

  const CardigannSetting({
    required this.name,
    this.type = 'text',
    this.label = '',
    this.defaultValue,
    this.options = const {},
  });

  factory CardigannSetting.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final opts = <String, String>{};
    if (rawOptions is Map) {
      rawOptions.forEach((k, v) {
        opts[k.toString()] = v.toString();
      });
    }

    return CardigannSetting(
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      label: map['label']?.toString() ?? map['name']?.toString() ?? '',
      defaultValue: map['default'],
      options: opts,
    );
  }
}

class CardigannLogin {
  final String path;
  final String method;
  final Map<String, dynamic> inputs;

  const CardigannLogin({
    this.path = '',
    this.method = 'post',
    this.inputs = const {},
  });

  factory CardigannLogin.fromMap(Map<String, dynamic> map) {
    return CardigannLogin(
      path: map['path']?.toString() ?? '',
      method: (map['method']?.toString() ?? 'post').toLowerCase(),
      inputs: map['inputs'] is Map
          ? Map<String, dynamic>.from(map['inputs'])
          : const {},
    );
  }
}

class CardigannSearch {
  final List<CardigannPath> paths;
  final Map<String, dynamic> inputs;
  final CardigannRow rows;
  final Map<String, CardigannField> fields;

  const CardigannSearch({
    this.paths = const [],
    this.inputs = const {},
    required this.rows,
    this.fields = const {},
  });
}

class CardigannPath {
  final String path;
  final String method;
  final List<dynamic> categories;
  final Map<String, dynamic> inputs;
  final Map<String, String> headers;
  final String? responseType; // 'html' or 'json'

  const CardigannPath({
    this.path = '/',
    this.method = 'get',
    this.categories = const [],
    this.inputs = const {},
    this.headers = const {},
    this.responseType,
  });

  factory CardigannPath.fromMap(Map<String, dynamic> map) {
    final headersMap = <String, String>{};
    if (map['headers'] is Map) {
      (map['headers'] as Map).forEach((k, v) {
        headersMap[k.toString()] = v.toString();
      });
    }

    final respObj = map['response'];
    final respType = respObj is Map
        ? respObj['type']?.toString().toLowerCase()
        : map['response_type']?.toString().toLowerCase();

    return CardigannPath(
      path: map['path']?.toString() ?? '/',
      method: (map['method']?.toString() ?? 'get').toLowerCase(),
      categories: map['categories'] is List ? List.from(map['categories']) : const [],
      inputs: map['inputs'] is Map
          ? Map<String, dynamic>.from(map['inputs'])
          : const {},
      headers: headersMap,
      responseType: respType,
    );
  }
}

class CardigannRow {
  final String selector;
  final String? attribute;
  final List<CardigannFilter> filters;
  final int? after;
  final int? before;

  const CardigannRow({
    required this.selector,
    this.attribute,
    this.filters = const [],
    this.after,
    this.before,
  });

  factory CardigannRow.fromMap(Map<String, dynamic> map) {
    final filterList = <CardigannFilter>[];
    if (map['filters'] is List) {
      for (final f in map['filters']) {
        if (f is Map) {
          filterList.add(CardigannFilter.fromMap(Map<String, dynamic>.from(f)));
        }
      }
    }

    return CardigannRow(
      selector: map['selector']?.toString() ?? '',
      attribute: map['attribute']?.toString(),
      filters: filterList,
      after: map['after'] is int ? map['after'] : int.tryParse(map['after']?.toString() ?? ''),
      before: map['before'] is int ? map['before'] : int.tryParse(map['before']?.toString() ?? ''),
    );
  }
}

class CardigannField {
  final String name;
  final String? selector;
  final String? attribute;
  final String? text;
  final bool optional;
  final String? defaultVal;
  final List<CardigannFilter> filters;
  final Map<String, dynamic>? caseConditions;

  const CardigannField({
    required this.name,
    this.selector,
    this.attribute,
    this.text,
    this.optional = false,
    this.defaultVal,
    this.filters = const [],
    this.caseConditions,
  });

  factory CardigannField.fromMap(String name, Map<String, dynamic> map) {
    final filterList = <CardigannFilter>[];
    if (map['filters'] is List) {
      for (final f in map['filters']) {
        if (f is Map) {
          filterList.add(CardigannFilter.fromMap(Map<String, dynamic>.from(f)));
        }
      }
    }

    Map<String, dynamic>? cases;
    if (map['case'] is Map) {
      cases = Map<String, dynamic>.from(map['case']);
    }

    return CardigannField(
      name: name,
      selector: map['selector']?.toString(),
      attribute: map['attribute']?.toString(),
      text: map['text']?.toString(),
      optional: map['optional'] == true,
      defaultVal: map['default']?.toString(),
      filters: filterList,
      caseConditions: cases,
    );
  }
}

class CardigannFilter {
  final String name;
  final dynamic args;

  const CardigannFilter({
    required this.name,
    this.args,
  });

  factory CardigannFilter.fromMap(Map<String, dynamic> map) {
    return CardigannFilter(
      name: map['name']?.toString() ?? '',
      args: map['args'],
    );
  }
}

/// Parser for Cardigann YAML definition strings.
class CardigannParser {
  static CardigannDefinition parseYaml(String yamlContent) {
    final dynamic loaded = loadYaml(yamlContent);
    if (loaded == null || loaded is! Map) {
      throw FormatException('Invalid Cardigann YAML format: root must be a mapping');
    }

    final data = _convertYamlToDart(loaded) as Map<String, dynamic>;

    final id = (data['id']?.toString() ?? data['name']?.toString() ?? 'indexer')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    final name = data['name']?.toString() ?? id;
    final description = data['description']?.toString() ?? '';
    final language = data['language']?.toString() ?? 'en-US';
    final type = data['type']?.toString() ?? 'public';
    final encoding = data['encoding']?.toString() ?? 'UTF-8';
    final useWebview = data['useWebview'] == true || data['use_webview'] == true;

    // links
    final links = <String>[];
    if (data['links'] is List) {
      for (final item in data['links']) {
        if (item != null) {
          links.add(item.toString());
        }
      }
    } else if (data['link'] != null) {
      links.add(data['link'].toString());
    }

    // caps
    final capsMap = data['caps'] is Map ? data['caps'] as Map<String, dynamic> : <String, dynamic>{};
    final categoryMappings = <CardigannCategoryMapping>[];
    if (capsMap['categorymappings'] is List) {
      for (final cm in capsMap['categorymappings']) {
        if (cm is Map) {
          categoryMappings.add(CardigannCategoryMapping.fromMap(Map<String, dynamic>.from(cm)));
        }
      }
    }
    if (capsMap['categories'] is Map) {
      (capsMap['categories'] as Map).forEach((k, v) {
        final catVal = TorznabCategories.parseCategory(v);
        categoryMappings.add(CardigannCategoryMapping(
          id: k.toString(),
          cat: catVal,
          desc: v?.toString() ?? '',
        ));
      });
    }
    final modes = <String, List<String>>{};
    if (capsMap['modes'] is Map) {
      (capsMap['modes'] as Map).forEach((k, v) {
        if (v is List) {
          modes[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }
    final caps = CardigannCaps(categorymappings: categoryMappings, modes: modes);

    // settings
    final settings = <CardigannSetting>[];
    if (data['settings'] is List) {
      for (final s in data['settings']) {
        if (s is Map) {
          settings.add(CardigannSetting.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    // login
    CardigannLogin? login;
    if (data['login'] is Map) {
      login = CardigannLogin.fromMap(data['login'] as Map<String, dynamic>);
    }

    // search
    final searchMap = data['search'] is Map ? data['search'] as Map<String, dynamic> : <String, dynamic>{};

    final paths = <CardigannPath>[];
    if (searchMap['paths'] is List) {
      for (final p in searchMap['paths']) {
        if (p is Map) {
          paths.add(CardigannPath.fromMap(Map<String, dynamic>.from(p)));
        }
      }
    }
    if (paths.isEmpty) {
      paths.add(const CardigannPath(path: '/'));
    }

    final searchInputs = searchMap['inputs'] is Map
        ? Map<String, dynamic>.from(searchMap['inputs'])
        : <String, dynamic>{};

    final rowsMap = searchMap['rows'] is Map
        ? Map<String, dynamic>.from(searchMap['rows'])
        : <String, dynamic>{'selector': ''};
    final rows = CardigannRow.fromMap(rowsMap);

    final fields = <String, CardigannField>{};
    if (searchMap['fields'] is Map) {
      (searchMap['fields'] as Map).forEach((k, v) {
        if (v is Map) {
          fields[k.toString()] =
              CardigannField.fromMap(k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }

    final search = CardigannSearch(
      paths: paths,
      inputs: searchInputs,
      rows: rows,
      fields: fields,
    );

    return CardigannDefinition(
      id: id,
      name: name,
      description: description,
      language: language,
      type: type,
      encoding: encoding,
      links: links,
      caps: caps,
      settings: settings,
      login: login,
      search: search,
      useWebview: useWebview,
      rawYaml: yamlContent,
    );
  }

  static dynamic _convertYamlToDart(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _convertYamlToDart(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map(_convertYamlToDart).toList();
    }
    return yaml;
  }
}
