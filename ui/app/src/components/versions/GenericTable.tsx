interface TableProps<T> {
  data: T[];
  columns: { key: string; name: string; render: (item: T) => JSX.Element }[];
}

export const GenericTable = <T,>({ data, columns }: TableProps<T>) => {
  return (
    <table style={{ width: "auto", borderCollapse: "collapse", fontSize: "16px" }}>
      <thead>
        <tr style={{ backgroundColor: "#f3f3f3", textAlign: "left", height: "40px" }}>
          {columns.map((col, index) => (
            <th
              key={col.key}
              style={{
                padding: "10px",
                borderBottom: "2px solid #ccc",
                borderRight: "1px solid #ddd",
                textAlign: "center",
                minWidth: index === 0 ? "max-content" : "6ch",
                maxWidth: index === 0 ? "250px" : "8ch",
                whiteSpace: "nowrap",
              }}
            >
              {col.name}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.map((item, index) => (
          <tr key={index} style={{ height: "50px", borderBottom: "1px solid #ddd" }}>
            {columns.map((col, colIndex) => (
              <td
                key={col.key}
                style={{
                  padding: "10px",
                  borderRight: "1px solid #ddd",
                  textAlign: "center",
                  verticalAlign: "middle",
                  minWidth: colIndex === 0 ? "max-content" : "6ch",
                  maxWidth: colIndex === 0 ? "250px" : "8ch",
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                {col.render(item)}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
};
