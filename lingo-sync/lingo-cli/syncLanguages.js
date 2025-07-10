import fs from 'fs';
import path from 'path';
import fetch from './fetch.js';

// 将非 ASCII 字符转换为 Unicode 字符串
function toUnicodeStringNonASCII(str) {
  return str.split('').map(char => {
    const code = char.charCodeAt(0);
    if (code < 128) {
      // ASCII 字符不进行转义
      return char;
    }
    const hexCode = code.toString(16).toUpperCase();
    return `\\u${'0000'.substring(0, 4 - hexCode.length) + hexCode}`;
  }).join('');
}

// 创建 Lingo 内容
const createContent = (translations, fileConfig, lingoConfig) => {
  let content = ''
  Object.entries(translations).forEach(([key, value]) => {
    const line = fileConfig.template.replace(/({{key}}|{{value}})/g, (placeholder) => {
      if (placeholder === '{{key}}') {
        if (lingoConfig.keyReplaces?.length) {
          lingoConfig.keyReplaces.forEach((replace) => {
            key = key.replaceAll(replace.from, replace.to);
          });
        }
        return key;
      }
      if (placeholder === '{{value}}') {
        if (lingoConfig.valueReplaces?.length) {
          lingoConfig.valueReplaces.forEach((replace) => {
            value = value.replaceAll(replace.from, replace.to);
          });
        }
        if (lingoConfig.valueToUnicode) {
          value = toUnicodeStringNonASCII(value);
        }
        return value;
      }
    });
    content += line + '\n';
  });
  return content.replace(/\n$/, '')
}

// 将翻译插入文件
const insertTranslationsToFile = ({
  currentDir,
  languageFilePath,
  languageCode,
  fileConfig,
  languageData,
  lingoConfig
}) => {
  // 构建文件路径
  const filePath = path.join(currentDir, languageFilePath);
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    return;
  }

  // 创建临时文件名
  const tempFilename = `${filePath}.tmp`;
  const readStream = fs.createReadStream(filePath, { encoding: 'utf8' });
  const writeStream = fs.createWriteStream(tempFilename);

  let lineBuffer = '';
  let content
  let startTrans = false;

  // 读取文件数据
  readStream.on('data', chunk => {
    lineBuffer += chunk;
    let lines = lineBuffer.split('\n');

    // 最后一个元素可能是不完整的行，因此保留在缓冲区中
    lineBuffer = lines.pop();
    const translations = languageData[languageCode];
    content = createContent(translations, fileConfig, lingoConfig);
    lines.forEach(line => {
      if (!startTrans) {
        writeStream.write(`${line}\n`);
      }
      if (line.includes(fileConfig.startTag)) {
        startTrans = true;
      }
      if (line.includes(fileConfig.endTag)) {
        writeStream.write(`${content}\n${line}\n`);
        startTrans = false;
      }
    });
  });


  // 读取结束时的处理
  readStream.on('end', () => {
    // 写入缓冲区中的任何剩余文本
    if (lineBuffer.length > 0) {
      writeStream.write(lineBuffer);
    }
    writeStream.end(() => {
      // 重命名临时文件为原始文件
      fs.rename(tempFilename, filePath, err => {
        if (err) {
          console.error('Error renaming file:', err);
        } else if (content) {
          console.log(`File "${languageFilePath}" modified successfully`);
        } else {
          console.log(`File "${languageFilePath}" not modified`);
        }
      });
    });
  });

  // 处理读取错误
  readStream.on('error', err => {
    console.error('Error reading file:', err);
  });

  // 处理写入错误
  writeStream.on('error', err => {
    console.error('Error writing file:', err);
  });
}

// 同步语言文件
export default async function syncLanguages(lingoConfig, asI18nConfig) {
  const currentDir = process.cwd();
  const { hostname, fileConfig, languageFiles, port, resources } = lingoConfig;

  const results = [];

  // 从 asI18nConfig 中获取 api-path 和 token
  const apiPath = asI18nConfig.lingo['api-path'];
  const token = asI18nConfig.lingo.token;

  if (!apiPath || !token) {
    console.error('Error: api-path or token not found in as_i18n.yaml');
    process.exit(1);
  }

  for (const { dataPath } of resources) {
    const languageRawStringData = await fetch({
      hostname: hostname,
      port: Number(port ?? 80),
      path: apiPath, // 使用从 as_i18n.yaml 获取的 api-path
      method: 'GET',
      headers: {
        'Authorization': `${token}`, // 使用从 as_i18n.yaml 获取的 token
        'Content-Type': 'application/json; charset=utf-8',
        'Accept-Charset': 'utf-8',
      },
    });

    let responseData;
    try {
      responseData = JSON.parse(languageRawStringData);
    } catch (err) {
      console.error('Error parsing api JSON:', err);
      process.exit(1);
    }

    if (responseData.code !== 200) {
      console.error('Error fetching api:', responseData.message);
      process.exit(1);
    }

    let languageRawData;
    if (dataPath) {
      languageRawData = responseData;
      dataPath.split('.').forEach((key) => {
        languageRawData = languageRawData[key];
      });
    } else {
      languageRawData = responseData.data;
    }

    results.push(...languageRawData);
  }

  // 处理语言数据
  const languageData = results.reduce((acc, item) => {
    acc.longest[item.key] = item.longest_language;
    item.languages.forEach((language) => {
      if (!acc[language.code]) {
        acc[language.code] = {};
      }
      acc[language.code][item.key] = language.value;
    });
    return acc;
  }, { longest: {} });

  // 插入翻译到文件
  languageFiles.forEach((languageFile) => {
    if (languageFile.path) {
      insertTranslationsToFile({
        currentDir,
        languageFilePath: languageFile.path,
        fileConfig,
        languageData,
        lingoConfig,
        languageCode: languageFile.code,
      })
    }
    if (languageFile.paths) {
      languageFile.paths.forEach((languageFilePath) => {
        insertTranslationsToFile({
          currentDir,
          languageFilePath,
          fileConfig,
          languageData,
          lingoConfig,
          languageCode: languageFile.code,
        })
      });
    }
  });
}