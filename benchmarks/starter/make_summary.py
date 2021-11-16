#!/usr/bin/env python
import argparse
import csv
import statistics


def read_csv_columns(csv_path):
    with open(csv_path, "r") as csvfile:
        reader = csv.DictReader(csvfile)
        res = {h: [] for h in reader.fieldnames}
        for line_dict in reader:
            for h, val in line_dict.items():
                res[h].append(float(val))

    return res


def summarise_array(x):
    return {
        "median": statistics.median(x),
        "mean": statistics.mean(x),
        "stdev": statistics.stdev(x),
        "minimum": min(x),
        "maximum": max(x),
    }


def save_md_summary(summary, output_path):
    lines = []

    row_names = list(summary.keys())
    col_names = ["init file"] + list(summary[row_names[0]].keys())
    lines.append(" | ".join(col_names))
    lines.append(" | ".join("---" for _ in col_names))

    for row_n in row_names:
        l = [row_n] + [str(round(x, 1)) + 'ms' for x in summary[row_n].values()]
        lines.append(" | ".join(l))

    lines = ["| " + l + " |\n" for l in lines]

    with open(output_path, "w") as output:
        for l in lines:
            output.write(l)


def compute_summary(csv_path):
    columns = read_csv_columns(csv_path)
    return {h: summarise_array(x) for h, x in columns.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_csv", help="path to file with startup times in csv format", type=str
    )
    parser.add_argument(
        "output_md",
        help="output path where markdown summary table will be written",
        type=str,
    )
    args = parser.parse_args()

    save_md_summary(compute_summary(args.input_csv), args.output_md)


if __name__ == "__main__":
    main()
