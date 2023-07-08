module tpstv

pub struct Rule[S] {
	name        string [required]
	description string
	start       S      [required]
	end         S      [required]
	stimulus    string [required]
}

pub struct Protocol[S] {
	name        string    [required]
	description string
	types       []string  [required]
	rules       []Rule[S] [required]
}
