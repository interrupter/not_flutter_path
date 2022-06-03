class NotPath {
  static const SUB_PATH_START = '{';
  static const SUB_PATH_END = '}';
  static const PATH_SPLIT = '.';
  static const PATH_START_OBJECT = ':';
  static const PATH_START_HELPERS = '::';
  static const FUNCTION_MARKER = '()';
  static const MAX_DEEP = 10;

  ///
  /// Returns first subpath in path
  /// if subpath not closed will return it anyway
  /// @param {string} path path in string notation
  /// @return {string|null} subpath or null if no sub path were found
  ///
  static String findNextSubPath(String path) {
    String subPath = '';
    bool find = false;
    for (int i = 0; i < path.length; i++) {
      if (path[i] == SUB_PATH_START) {
        find = true;
        subPath = '';
      } else {
        if ((path[i] == SUB_PATH_END) && find) {
          return subPath;
        } else {
          subPath += path[i];
        }
      }
    }
    return find ? subPath : '';
  }

  ///
  /// Replace sub-path in parent path by parsed version
  /// @param {string} path path to process
  /// @param {string} sub sub path to replace
  /// @param {string} parsed parsed sub path
  /// @return {string} parsed path
  ///
  static String replaceSubPath(String path, String sub, String parsed) {
    String subf = SUB_PATH_START + sub + SUB_PATH_END;
    int i = 0;
    while (path.contains(subf) && i < MAX_DEEP) {
      path = path.replaceFirst(subf, parsed);
      i++;
    }
    return path;
  }

  ///
  /// Parses path while there any sub-paths
  /// @param {string} path raw unparsed path
  /// @param {object} item data
  /// @param {object} helpers helpers
  /// @return {string} parsed path
  ///
  static parseSubs(path, item, helpers) {
    String subPath = NotPath.findNextSubPath(path);
    String subPathParsed;
    int i = 0;
    while (subPath.isNotEmpty) {
      subPathParsed = NotPath.getValueByPath(
          subPath.contains(PATH_START_HELPERS) ? helpers : item,
          subPath,
          item,
          helpers);
      path = NotPath.replaceSubPath(path, subPath, subPathParsed);
      i++;
      if (i > MAX_DEEP) {
        break;
      }
      subPath = NotPath.findNextSubPath(path);
    }
    return path;
  }

  ///
  /// Get property value
  /// @param {string} path path to property
  /// @param {object} item item object
  /// @param {object} helpers helpers object
  ///
  static dynamic get(
    String path,
    Map<String, dynamic> item, [
    Map<String, dynamic> helpers = const {},
  ]) {
    switch (path) {
      case PATH_START_OBJECT:
        return item;
      case PATH_START_HELPERS:
        return helpers;
    }
    path = NotPath.parseSubs(path, item, helpers);
    return NotPath.getValueByPath(
        path.contains(PATH_START_HELPERS) ? helpers : item,
        path,
        item,
        helpers);
  }

  ///
  /// Set property value
  /// @param {string} path path to property
  /// @param {object} item item object
  /// @param {object} helpers helpers object
  /// @param {any} attrValue value we want to assign
  ///
  static void set({
    required String path,
    required dynamic item,
    dynamic helpers,
    required dynamic attrValue,
  }) {
    String subPath = NotPath.findNextSubPath(path);
    String subPathParsed;
    int i = 0;
    while (subPath.isNotEmpty) {
      subPathParsed = NotPath.getValueByPath(
          subPath.contains(PATH_START_HELPERS) ? helpers : item,
          subPath,
          item,
          helpers);
      path = NotPath.replaceSubPath(path, subPath, subPathParsed);
      if (i > MAX_DEEP) {
        break;
      }
      subPath = NotPath.findNextSubPath(path);
      i++;
    }
    NotPath.setValueByPath(item, path, attrValue);
  }

  ///
  /// Set target property to null
  /// @param {string} path path to property
  /// @param {object} item item object
  /// @param {object} helpers helpers object
  ///
  static void unset(path, item, helpers) {
    NotPath.set(path: path, item: item, helpers: helpers, attrValue: null);
  }

  ///
  /// Parses step key, transforms it to end-form
  /// @param {string} step not parsed step key
  /// @param {object} item item object
  /// @param {object} helper helpers object
  /// @return {string|number} parsed step key
  ///
  static parsePathStep(String step, dynamic item, dynamic helper) {
    String rStep;
    if (step.indexOf(PATH_START_HELPERS) == 0 && helper) {
      rStep = step.replaceFirst(PATH_START_HELPERS, '');
      if (rStep.indexOf(FUNCTION_MARKER) == rStep.length - 2) {
        rStep = rStep.replaceFirst(FUNCTION_MARKER, '');
        if (helper[rStep] is Function) {
          return helper[rStep](item, null);
        }
      } else {
        return helper[rStep];
      }
    } else {
      if (step.indexOf(PATH_START_OBJECT) == 0 && item) {
        rStep = step.replaceFirst(PATH_START_OBJECT, '');
        if (rStep.indexOf(FUNCTION_MARKER) == rStep.length - 2) {
          rStep = rStep.replaceFirst(FUNCTION_MARKER, '');
          if (item[rStep] is Function) {
            return item[rStep](item, null);
          }
        } else {
          return item[rStep];
        }
      }
    }
    return step;
  }

  ///{::fieldName}.result
  ///{}
  ///{fieldName: 'targetRecordField'}
  /////['targetRecordField', 'result']
  ///
  /// Transforms path with sub paths to path without
  /// @param {string|array} path path to target property
  /// @param {object} item item object
  /// @param {object} helper helper object
  /// @return {array} parsed path
  ///
  static List<String> parsePath(dynamic path, dynamic item, dynamic helper) {
    List<String> pathParts = [];
    if (path is String) {
      pathParts = path.split(PATH_SPLIT);
    } else if (path is List<String>) {
      pathParts = path;
    } else {
      throw Exception('WRONG path type');
    }
    for (int i = 0; i < pathParts.length; i++) {
      pathParts[i] = NotPath.parsePathStep(pathParts[i], item, helper);
    }
    return pathParts;
  }

  ///
  /// Transforms path from string notation to array of keys
  /// @param {string|array} path  input path, if array does nothing
  /// @return {array} path in array notation
  ///
  static List<String> normilizePath(dynamic path) {
    if (path is List<String>) {
      return path;
    } else {
      while (path.includes(PATH_START_OBJECT)) {
        path = path.replaceFirst(PATH_START_OBJECT, '');
      }
      return path.split(PATH_SPLIT);
    }
  }

  /*
		small = ["todo"],
		big = ["todo", "length"]
		return true;

	*/

  ///
  /// Identifies if first path includes second, compared from start,
  /// no floating start position inside ['join', 'me'], ['me']
  /// will result in false
  /// @param {array} big where we will search
  /// @param {array} small what we will search
  /// @return {boolean} if we succeed
  ///
  static bool ifFullSubPath(List<String> big, List<String> small) {
    if (big.length < small.length) {
      return false;
    }
    for (int t = 0; t < small.length; t++) {
      if (small[t] != big[t]) {
        return false;
      }
    }
    return true;
  }

  ///
  /// Getter through third object
  /// Path is parsed, no event triggering for notRecord
  /// @param {object} object object to be used as getter
  /// @param {string|array} attrPath path to property
  /// @param {object} item supporting data
  /// @param {helpers} object  supporting helpers
  ///
  static dynamic getValueByPath(
      dynamic object, dynamic attrPath, dynamic item, dynamic helpers) {
    attrPath = NotPath.normilizePath(attrPath);
    String attrName = attrPath.shift();
    bool isFunction = attrName.contains(FUNCTION_MARKER);
    if (isFunction) {
      attrName = attrName.replaceFirst(FUNCTION_MARKER, '');
    }
    if ((object is Map<String, dynamic>) && object[attrName] != null) {
      dynamic newObj =
          isFunction ? object[attrName]({item, helpers}) : object[attrName];
      if (attrPath.length > 0) {
        return NotPath.getValueByPath(newObj, attrPath, item, helpers);
      } else {
        return newObj;
      }
    } else {
      return null;
    }
  }

  ///
  /// Setter through third object
  /// Path is parsed, no event triggering for notRecord
  /// @param {object} object object to be modified
  /// @param {string|array} attrPath path to property
  /// @param {any} attrValue  value to assign
  ///
  static void setValueByPath(
      dynamic object, dynamic attrPath, dynamic attrValue) {
    attrPath = NotPath.normilizePath(attrPath);
    String attrName = attrPath.shift();
    if (attrPath.length > 0) {
      if (object[attrName] == null) {
        object[attrName] = {};
      }
      NotPath.setValueByPath(object[attrName], attrPath, attrValue);
    } else {
      object[attrName] = attrValue;
    }
  }

  ///
  /// Joins passed in strings with PATH_SPLIT
  /// @param {string} arguments path to be glued
  /// @return {string} composite path
  ///
  static String join(List<String> list) {
    return list.join(PATH_SPLIT);
  }
}
