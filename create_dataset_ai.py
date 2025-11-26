import json

def create_dataset():
    data_list = []
    print("=== Dataset Builder (English / Any Language) ===")
    print("Type 'exit' when you're done")
    print("-" * 40)

    while True:
        instruction = input("❓ Model instruction/question: ").strip()
        if instruction.lower() == "exit":
            break
        if not instruction:
            print("❌ Empty instruction.")
            continue

        context = input("📎 Context / Input (press Enter to skip): ").strip()
        output = input("📌 Expected answer: ").strip()
        if output.lower() == "exit":
            break
        if not output:
            print("❌ Empty answer.")
            continue

        entry = {
            "instruction": instruction,
            "input": context,
            "output": output,
        }
        data_list.append(entry)
        print("✔ Saved.")
        print(json.dumps(entry, ensure_ascii=False, indent=4))
        print("-" * 40)

    file_name = input("📁 File name? (default = dataset.json): ").strip() or "dataset.json"
    with open(file_name, "w", encoding="utf-8") as f:
        json.dump(data_list, f, ensure_ascii=False, indent=4)

    print("\n" + "=" * 40)
    print(f"🎉 File created: {file_name}")
    print(f"📊 Total entries: {len(data_list)}")

if __name__ == "__main__":
    create_dataset()
