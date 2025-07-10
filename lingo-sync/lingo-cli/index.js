#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';
import syncLanguages from './syncLanguages.js';

const lingoConfigFilename = 'lingoconfig.json';
const asI18nFilename = 'as_i18n.yaml';
const currentDir = process.cwd();
const lingoConfigPath = path.join(currentDir, lingoConfigFilename);

// 循环向上查找 as_i18n.yaml 文件
function findAsI18nFile(startDir) {
  let currentPath = startDir;
  
  while (currentPath !== path.dirname(currentPath)) {
    const asI18nPath = path.join(currentPath, asI18nFilename);
    if (fs.existsSync(asI18nPath)) {
      return asI18nPath;
    }
    currentPath = path.dirname(currentPath);
  }
  
  // 检查根目录
  const rootAsI18nPath = path.join(currentPath, asI18nFilename);
  if (fs.existsSync(rootAsI18nPath)) {
    return rootAsI18nPath;
  }
  
  return null;
}

// 读取 lingoconfig.json
fs.readFile(lingoConfigPath, 'utf8', (err, lingoData) => {
  if (err) {
    if (err.code === 'ENOENT') {
      console.error(`File not found: ${lingoConfigFilename}`);
    } else {
      console.error('Error reading lingoconfig.json:', err);
    }
    process.exit(1);
  }

  // 查找 as_i18n.yaml 文件
  const asI18nPath = findAsI18nFile(currentDir);
  if (!asI18nPath) {
    console.error(`File not found: ${asI18nFilename} (searched in current directory and parent directories)`);
    process.exit(1);
  }

  // 读取 as_i18n.yaml
  fs.readFile(asI18nPath, 'utf8', (err, asI18nData) => {
    if (err) {
      console.error('Error reading as_i18n.yaml:', err);
      process.exit(1);
    }

    try {
      const lingoConfig = JSON.parse(lingoData);
      const asI18nConfig = yaml.load(asI18nData);
      syncLanguages(lingoConfig, asI18nConfig);
    } catch (err) {
      console.error('Error parsing configuration files:', err);
      process.exit(1);
    }
  });
});
