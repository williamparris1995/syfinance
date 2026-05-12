#!/usr/bin/env python3
"""
代码质量校验工具
验证生成的Rust代码是否符合CODING_STANDARDS.md规范
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

class CodeValidator:
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.src_dir = project_root / "src-tauri" / "src"
        self.errors: List[Tuple[str, int, str]] = []
        self.warnings: List[Tuple[str, int, str]] = []
    
    def validate_all(self) -> bool:
        """运行所有验证规则"""
        print("🔍 开始代码质量检查...\n")
        
        # 检查所有Rust文件
        rust_files = list(self.src_dir.rglob("*.rs"))
        
        for file_path in rust_files:
            # 跳过测试文件（允许硬编码）
            if "tests" in str(file_path) or file_path.name.endswith("_test.rs"):
                continue
            
            self.validate_file(file_path)
        
        # 输出结果
        self.print_results()
        
        return len(self.errors) == 0
    
    def validate_file(self, file_path: Path):
        """验证单个文件"""
        try:
            content = file_path.read_text(encoding='utf-8')
            lines = content.split('\n')
            
            # 规则1: 检查硬编码SQL字段名
            self.check_hardcoded_sql(file_path, content, lines)
            
            # 规则2: 检查硬编码字符串匹配
            self.check_hardcoded_string_match(file_path, content, lines)
            
            # 规则3: 检查println!使用
            self.check_println_usage(file_path, content, lines)
            
            # 规则4: 检查log宏使用（应该用tracing）
            self.check_log_usage(file_path, content, lines)
            
            # 规则5: 检查enum是否使用serde
            self.check_enum_serde(file_path, content, lines)
            
        except Exception as e:
            self.warnings.append((str(file_path), 0, f"无法读取文件: {e}"))
    
    def check_hardcoded_sql(self, file_path: Path, content: str, lines: List[str]):
        """检查硬编码SQL字段名"""
        # 检查sqlx::query!或query_as!
        pattern = r'sqlx::query(?:_as)?!\s*\('
        
        for i, line in enumerate(lines, 1):
            if re.search(pattern, line):
                # 检查是否在repository文件中
                if "repositories" in str(file_path):
                    self.errors.append((
                        str(file_path),
                        i,
                        "❌ 禁止使用sqlx::query!硬编码SQL，请使用SeaORM"
                    ))
    
    def check_hardcoded_string_match(self, file_path: Path, content: str, lines: List[str]):
        """检查硬编码字符串匹配"""
        # 检查 match s { "STRING" => ... } 模式
        in_match = False
        match_start = 0
        
        for i, line in enumerate(lines, 1):
            # 检测match语句开始
            if re.search(r'match\s+\w+\s*\{', line):
                in_match = True
                match_start = i
            
            # 在match块中检查字符串字面量
            if in_match and re.search(r'^\s*"[A-Z_]+"?\s*=>', line):
                # 排除测试代码
                if "#[cfg(test)]" not in content[:content.find(line)]:
                    self.errors.append((
                        str(file_path),
                        i,
                        "❌ 禁止硬编码字符串匹配，请使用serde的rename_all"
                    ))
            
            # 检测match块结束
            if in_match and line.strip() == '}':
                in_match = False
    
    def check_println_usage(self, file_path: Path, content: str, lines: List[str]):
        """检查println!使用"""
        for i, line in enumerate(lines, 1):
            if 'println!' in line and not line.strip().startswith('//'):
                self.errors.append((
                    str(file_path),
                    i,
                    "❌ 禁止使用println!，请使用tracing宏（info!, debug!, error!等）"
                ))
    
    def check_log_usage(self, file_path: Path, content: str, lines: List[str]):
        """检查log宏使用"""
        log_macros = ['log::info!', 'log::debug!', 'log::warn!', 'log::error!']
        
        for i, line in enumerate(lines, 1):
            for macro in log_macros:
                if macro in line and not line.strip().startswith('//'):
                    self.warnings.append((
                        str(file_path),
                        i,
                        f"⚠️  建议使用tracing代替log: {macro} -> tracing::{macro.split('::')[1]}"
                    ))
    
    def check_enum_serde(self, file_path: Path, content: str, lines: List[str]):
        """检查enum是否使用serde"""
        # 查找enum定义
        enum_pattern = r'pub\s+enum\s+(\w+)\s*\{'
        
        for i, line in enumerate(lines, 1):
            match = re.search(enum_pattern, line)
            if match:
                enum_name = match.group(1)
                
                # 检查前面几行是否有#[derive(...Serialize...)]
                check_lines = lines[max(0, i-5):i]
                has_serde = any('Serialize' in l and 'Deserialize' in l for l in check_lines)
                
                if not has_serde:
                    # 检查是否是内部enum（不需要序列化）
                    if not any(kw in enum_name for kw in ['Error', 'Event']):
                        self.warnings.append((
                            str(file_path),
                            i,
                            f"⚠️  enum {enum_name} 可能需要添加 #[derive(Serialize, Deserialize)]"
                        ))
    
    def print_results(self):
        """打印验证结果"""
        print("\n" + "="*80)
        
        if self.errors:
            print(f"\n❌ 发现 {len(self.errors)} 个错误:\n")
            for file_path, line_num, message in self.errors:
                print(f"  {file_path}:{line_num}")
                print(f"    {message}\n")
        
        if self.warnings:
            print(f"\n⚠️  发现 {len(self.warnings)} 个警告:\n")
            for file_path, line_num, message in self.warnings:
                print(f"  {file_path}:{line_num}")
                print(f"    {message}\n")
        
        if not self.errors and not self.warnings:
            print("\n✅ 所有检查通过！代码符合规范。\n")
        
        print("="*80)
        
        # 总结
        print(f"\n📊 检查总结:")
        print(f"  错误: {len(self.errors)}")
        print(f"  警告: {len(self.warnings)}")
        print()

def main():
    """主函数"""
    # 获取项目根目录
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # 创建验证器
    validator = CodeValidator(project_root)
    
    # 运行验证
    success = validator.validate_all()
    
    # 返回退出码
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
