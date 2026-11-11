#!/usr/bin/env python3
"""把 Markdown 报告转换为排版后的 Word 文档。

流程：pandoc 生成基础 docx → python-docx 统一中文字体与段落样式 →
补封面、目录域、页眉页脚 → 表格加边框与表头底色。
"""
import os
import subprocess
import tempfile

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SRC = os.path.join(ROOT, "docs", "report", "短视频数据管理系统-课程设计报告.md")
RAW = os.path.join(tempfile.gettempdir(), "short-video-report-raw.docx")
OUT = os.path.join(ROOT, "docs", "report", "短视频数据管理系统-课程设计报告.docx")

SONG = "宋体"
HEI = "黑体"
MONO = "Consolas"


def set_cn_font(run_or_style, ascii_font, cn_font, size=None, bold=None, color=None):
    font = run_or_style.font
    font.name = ascii_font
    if size is not None:
        font.size = Pt(size)
    if bold is not None:
        font.bold = bold
    if color is not None:
        font.color.rgb = RGBColor(*color)
    rpr = run_or_style.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:ascii"), ascii_font)
    rfonts.set(qn("w:hAnsi"), ascii_font)
    rfonts.set(qn("w:eastAsia"), cn_font)


def style_by_name(doc, *names):
    out = []
    for name in names:
        for s in doc.styles:
            if s.name == name:
                out.append(s)
                break
    return out


def add_field(paragraph, instr):
    run = paragraph.add_run()
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")
    instr_el = OxmlElement("w:instrText")
    instr_el.set(qn("xml:space"), "preserve")
    instr_el.text = instr
    fld_sep = OxmlElement("w:fldChar")
    fld_sep.set(qn("w:fldCharType"), "separate")
    txt = OxmlElement("w:t")
    txt.text = "（打开文档后按 F9 或允许自动更新即可生成目录）"
    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")
    run._r.append(fld_begin)
    run._r.append(instr_el)
    run._r.append(fld_sep)
    run._r.append(txt)
    run._r.append(fld_end)


def enable_update_fields(doc):
    settings = doc.settings.element
    node = OxmlElement("w:updateFields")
    node.set(qn("w:val"), "true")
    settings.append(node)


def shade(cell, hex_color):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tc_pr.append(shd)


def table_borders(table, color="B4B2A9", size=4):
    tbl_pr = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{edge}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), str(size))
        el.set(qn("w:space"), "0")
        el.set(qn("w:color"), color)
        borders.append(el)
    tbl_pr.append(borders)


def repeat_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    tr_pr.append(el)


def main():
    subprocess.run(
        ["pandoc", SRC, "-o", RAW, "--from", "gfm+pipe_tables", "--to", "docx",
         "--resource-path", os.path.dirname(SRC)],
        check=True,
    )

    doc = Document(RAW)

    # ---------- 页面设置 ----------
    for section in doc.sections:
        section.page_width = Cm(21)
        section.page_height = Cm(29.7)
        section.left_margin = Cm(2.6)
        section.right_margin = Cm(2.6)
        section.top_margin = Cm(2.5)
        section.bottom_margin = Cm(2.4)
        section.header_distance = Cm(1.4)
        section.footer_distance = Cm(1.4)

    # ---------- 样式 ----------
    normal = doc.styles["Normal"]
    set_cn_font(normal, "Times New Roman", SONG, 10.5, color=(0x2C, 0x2C, 0x2A))
    normal.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    normal.paragraph_format.space_after = Pt(3)

    for name in ("Body Text", "First Paragraph", "Compact"):
        for st in style_by_name(doc, name):
            set_cn_font(st, "Times New Roman", SONG, 10.5)
            st.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
            st.paragraph_format.space_after = Pt(3)

    for st in style_by_name(doc, "Body Text", "First Paragraph"):
        st.paragraph_format.first_line_indent = Pt(21)

    sizes = {"Heading 1": 16, "Heading 2": 13.5, "Heading 3": 12, "Heading 4": 11}
    for name, size in sizes.items():
        for st in style_by_name(doc, name):
            set_cn_font(st, HEI, HEI, size, bold=True, color=(0x1A, 0x1A, 0x18))
            pf = st.paragraph_format
            pf.space_before = Pt(16 if name == "Heading 1" else 12)
            pf.space_after = Pt(8 if name == "Heading 1" else 6)
            pf.keep_with_next = True
            pf.first_line_indent = Pt(0)

    for st in style_by_name(doc, "Title"):
        set_cn_font(st, HEI, HEI, 24, bold=True, color=(0x1A, 0x1A, 0x18))
        st.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER

    for st in style_by_name(doc, "Source Code"):
        set_cn_font(st, MONO, MONO, 9)
        st.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
        st.paragraph_format.space_after = Pt(2)
        st.paragraph_format.first_line_indent = Pt(0)

    for st in style_by_name(doc, "Verbatim Char"):
        set_cn_font(st, MONO, MONO, 9)

    for st in style_by_name(doc, "Image Caption", "Table Caption", "Caption"):
        set_cn_font(st, SONG, SONG, 9, color=(0x5F, 0x5E, 0x5A))
        st.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER

    # ---------- 删除与封面重复的标题，并把章节层级上移一级 ----------
    paras = list(doc.paragraphs)
    for i, p in enumerate(paras):
        if p.style is not None and p.style.name == "Heading 1":
            for follow in paras[i:i + 3]:
                follow._element.getparent().remove(follow._element)
            break

    shift = {"Heading 2": "Heading 1", "Heading 3": "Heading 2", "Heading 4": "Heading 3"}
    for p in doc.paragraphs:
        if p.style is not None and p.style.name in shift:
            p.style = doc.styles[shift[p.style.name]]

    # ---------- 表格美化 ----------
    for table in doc.tables:
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = True
        table_borders(table)
        # 让 Word 按内容自动分配列宽：清掉 pandoc 写死的等宽列宽
        tbl_pr = table._tbl.tblPr
        for tag in ("w:tblW", "w:tblLayout"):
            for el in tbl_pr.findall(qn(tag)):
                tbl_pr.remove(el)
        tbl_w = OxmlElement("w:tblW")
        tbl_w.set(qn("w:type"), "pct")
        tbl_w.set(qn("w:w"), "5000")
        tbl_pr.append(tbl_w)
        layout = OxmlElement("w:tblLayout")
        layout.set(qn("w:type"), "autofit")
        tbl_pr.append(layout)
        grid = table._tbl.find(qn("w:tblGrid"))
        if grid is not None:
            for col in list(grid):
                if col.get(qn("w:w")) is not None:
                    del col.attrib[qn("w:w")]
        for row in table.rows:
            for cell in row.cells:
                tc_pr = cell._tc.get_or_add_tcPr()
                for el in tc_pr.findall(qn("w:tcW")):
                    tc_pr.remove(el)
        for idx, row in enumerate(table.rows):
            if idx == 0:
                repeat_header(row)
            for cell in row.cells:
                if idx == 0:
                    shade(cell, "EDEAE0")
                for p in cell.paragraphs:
                    p.paragraph_format.first_line_indent = Pt(0)
                    p.paragraph_format.space_after = Pt(1)
                    p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
                    for run in p.runs:
                        run.font.size = Pt(9)
                        if idx == 0:
                            run.font.bold = True

    # ---------- 代码块加浅底 ----------
    for p in doc.paragraphs:
        if p.style is not None and p.style.name in ("Source Code",):
            p_pr = p._p.get_or_add_pPr()
            shd = OxmlElement("w:shd")
            shd.set(qn("w:val"), "clear")
            shd.set(qn("w:fill"), "F5F4EF")
            p_pr.append(shd)
            p.paragraph_format.left_indent = Cm(0.4)

    # ---------- 页眉页脚 ----------
    for section in doc.sections:
        header = section.header
        hp = header.paragraphs[0]
        hp.text = "短视频数据管理系统 · 课程设计报告"
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        for run in hp.runs:
            run.font.size = Pt(8.5)
            run.font.color.rgb = RGBColor(0x88, 0x87, 0x80)
            set_cn_font(run, "Times New Roman", SONG, 8.5, color=(0x88, 0x87, 0x80))

        footer = section.footer
        fp = footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        add_field(fp, " PAGE ")
        for run in fp.runs:
            run.font.size = Pt(9)
            set_cn_font(run, "Times New Roman", SONG, 9, color=(0x88, 0x87, 0x80))

    # ---------- 封面 ----------
    body = doc.element.body
    first = body[0]

    def new_par(text, size, bold=False, align=WD_ALIGN_PARAGRAPH.CENTER,
                space_before=0, space_after=6, color=(0x1A, 0x1A, 0x18)):
        p = doc.add_paragraph()
        p.alignment = align
        p.paragraph_format.first_line_indent = Pt(0)
        p.paragraph_format.space_before = Pt(space_before)
        p.paragraph_format.space_after = Pt(space_after)
        run = p.add_run(text)
        set_cn_font(run, HEI if bold else SONG, HEI if bold else SONG, size, bold=bold, color=color)
        return p

    cover = []
    cover.append(new_par("数据库系统原理  课程设计报告", 12, False, space_before=30, space_after=40,
                         color=(0x5F, 0x5E, 0x5A)))
    cover.append(new_par("短视频数据管理系统", 30, True, space_before=0, space_after=10))
    cover.append(new_par("的设计与实现", 30, True, space_before=0, space_after=36))

    info = doc.add_table(rows=5, cols=2)
    info.alignment = WD_TABLE_ALIGNMENT.CENTER
    info.autofit = True
    rows = [
        ("课程名称", "数据库系统原理"),
        ("设计题目", "短视频数据管理系统"),
        ("数据库", "MySQL 8.0.40（InnoDB / utf8mb4）"),
        ("小组成员", "＿＿＿＿＿＿  ＿＿＿＿＿＿  ＿＿＿＿＿＿  ＿＿＿＿＿＿"),
        ("完成日期", "2026 年 11 月"),
    ]
    for i, (k, v) in enumerate(rows):
        c0, c1 = info.rows[i].cells
        c0.text, c1.text = k, v
        for cell, bold in ((c0, True), (c1, False)):
            for p in cell.paragraphs:
                p.paragraph_format.first_line_indent = Pt(0)
                p.paragraph_format.space_after = Pt(4)
                for run in p.runs:
                    set_cn_font(run, SONG, SONG, 11, bold=bold)
        c0.width = Cm(3.6)
        c1.width = Cm(9.0)
    cover.append(info)

    brk = doc.add_paragraph()
    brk.add_run().add_break(WD_BREAK.PAGE)
    cover.append(brk)

    # 目录标题 + 目录域
    toc_title = new_par("目　录", 16, True, space_before=0, space_after=12)
    cover.append(toc_title)
    toc_p = doc.add_paragraph()
    toc_p.paragraph_format.first_line_indent = Pt(0)
    add_field(toc_p, r'TOC \o "1-3" \h \z \u')
    cover.append(toc_p)
    page_break2 = doc.add_paragraph()
    page_break2.add_run().add_break(WD_BREAK.PAGE)
    cover.append(page_break2)

    for el in cover:
        node = el._element if hasattr(el, "_element") else el._tbl
        first.addprevious(node)

    enable_update_fields(doc)
    doc.save(OUT)
    print("saved", OUT)


if __name__ == "__main__":
    main()
